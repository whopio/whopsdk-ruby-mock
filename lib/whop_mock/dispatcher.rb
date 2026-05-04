# frozen_string_literal: true

require_relative "dispatcher/filters"
require_relative "dispatcher/filter_search"
require_relative "dispatcher/filter_field_lookup"
require_relative "dispatcher/filter_sorting"
require_relative "dispatcher/graph_side_effects"
require_relative "dispatcher/graph_payloads"
require_relative "dispatcher/invoice_graph"
require_relative "dispatcher/lifecycle_sync"
require_relative "dispatcher/serializers"
require_relative "dispatcher/payment_graph"
require_relative "dispatcher/payout_graph"
require_relative "dispatcher/resource_ensurers"
require_relative "dispatcher/validators"

module WhopMock
  class Dispatcher
    include Filters
    include FilterFieldLookup
    include FilterSorting
    include FilterSearch
    include GraphSideEffects
    include GraphPayloads
    include InvoiceGraph
    include LifecycleSync
    include PaymentGraph
    include PayoutGraph
    include ResourceEnsurers
    include Serializers
    include Validators
    include ResourceNames

    PAGINATION_QUERY_KEYS = %w[after before first last limit].freeze

    # Resources that return transient responses (no id, not stored)
    TRANSIENT_CREATE_RESOURCES = [ACCOUNT_LINK].freeze

    def initialize(error_injector:, route_registry:, store:, id_generator:, example_generator:, status_transitions:,
                   response_builder:, paginator:)
      @error_injector = error_injector
      @matcher = RequestMatcher.new(route_registry)
      @store = store
      @id_generator = id_generator
      @example_generator = example_generator
      @status_transitions = status_transitions
      @response_builder = response_builder
      @paginator = paginator
    end

    def dispatch(method:, path:, query: {}, body: nil)
      match = @matcher.match(method, path)
      raise Error, "No mock route for #{method.upcase} #{path}" unless match

      route = match.route
      @error_injector.raise_if_prepared!(route)

      case route.action
      when :list
        validate_list_query!(route, query)
        records = filter_records(route.resource_name, query)
        records = sort_records(route.resource_name, records, query)
        [200, @paginator.paginate(records, limit: list_limit(query), after: query["after"])]
      when :search
        validate_list_query!(route, query)
        records = filter_records(route.resource_name, query)
        records = filter_by_query(route.resource_name, records, query["query"])
        records = sort_records(route.resource_name, records, query)
        [200, @paginator.paginate(records, limit: list_limit(query), after: query["after"])]
      when :fees
        records = fee_records(identifier_for(route, match.path_params))
        [200, @paginator.paginate(records, limit: list_limit(query), after: query["after"])]
      when :create
        payload = create_payload(body)
        validate_create_payload!(route, payload)
        payload = resolve_payment_token(payload) if route_resource_name(route) == PAYMENT_METHOD
        record = @example_generator.generate(route.resource_name, payload)
        record["id"] ||= @id_generator.generate(route.resource_name)

        # Transient resources (e.g., account_link) apply side effects but don't persist
        if TRANSIENT_CREATE_RESOURCES.include?(route_resource_name(route))
          result = apply_transient_side_effects(route.resource_name, record, payload)
          [201, build_resource(route, result)]
        else
          stored = @store.insert(route.resource_name, record)
          stored = apply_create_side_effects(route.resource_name, stored, payload)
          [201, build_resource(route, stored)]
        end
      when :retrieve
        record = @store.find(route.resource_name, identifier_for(route, match.path_params))
        raise NotFoundError, "#{route.resource_name} not found" unless record

        [200, build_resource(route, record)]
      when :update
        identifier = identifier_for(route, match.path_params)
        current = @store.find(route.resource_name, identifier)
        raise NotFoundError, "#{route.resource_name} not found" unless current

        attributes = stringify_keys(body || {})
        validate_update_payload!(route, current, attributes)
        record = @store.update(route.resource_name, identifier, attributes)
        record = apply_update_side_effects(route.resource_name, current, record, attributes)

        [200, build_resource(route, record)]
      when :delete
        record = @store.delete(route.resource_name, identifier_for(route, match.path_params))
        raise NotFoundError, "#{route.resource_name} not found" unless record

        [200, boolean_response?(route) || record]
      else
        [200, handle_custom_action(route, match.path_params, body)]
      end
    end

    private

    def handle_custom_action(route, path_params, body)
      identifier = identifier_for(route, path_params)
      current = @store.find(route.resource_name, identifier)
      raise NotFoundError, "#{route.resource_name} not found" unless current

      attributes = stringify_keys(body || {})
      validate_action!(route, current, attributes)
      updates = @status_transitions.apply(
        resource_name: route.resource_name,
        action: route.action,
        record: current.merge("_action_attributes" => attributes),
        attributes: body || {}
      )
      updated = @store.update(route.resource_name, identifier, updates) || current
      updated = apply_action_side_effects(route.resource_name, route.action, current, updated, attributes)
      boolean_response?(route) || build_resource(route, updated)
    end

    def create_payload(body)
      payload = stringify_keys(body || {})
      payload["body"].is_a?(Hash) ? payload["body"] : payload
    end

    def build_resource(route, record)
      @response_builder.build(resource_name: route.resource_name, record: record, schema: route.response_schema)
    end

    def route_resource_name(route)
      ResourceNames.normalize(route.resource_name)
    end

    def identifier_for(route, path_params)
      path_params.values.first || raise(Error, "No identifier available for #{route.path}")
    end

    def stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] =
          case value
          when Hash then stringify_keys(value)
          when Array then value.map { |item| item.is_a?(Hash) ? stringify_keys(item) : item }
          else value
          end
      end
    end

    def resolve_payment_token(payload)
      token_id = payload["payment_token"] || payload["payment_token_id"] || payload["token"]
      return payload unless token_id

      token = @store.find("payment_token", token_id)
      return payload unless token

      payload.merge(
        "brand" => token["brand"],
        "country" => token["country"],
        "exp_month" => token["exp_month"],
        "exp_year" => token["exp_year"],
        "last4" => token["last4"],
        "payment_token_id" => token["id"]
      )
    end

    def integer_param(value)
      Integer(value) if value
    rescue ArgumentError
      nil
    end

    def list_limit(query)
      integer_param(query["limit"]) || integer_param(query["first"]) || Paginator::DEFAULT_LIMIT
    end

    def pagination_query_key?(key)
      PAGINATION_QUERY_KEYS.include?(key.to_s)
    end

    def boolean_response?(route)
      route.response_schema.is_a?(Hash) && route.response_schema["type"] == "boolean"
    end

    def blank_value?(value)
      value.nil? || value == ""
    end

    def present_value?(value)
      !blank_value?(value)
    end

    def blank_hash?(value)
      !value.is_a?(Hash) || value.empty?
    end
  end
end
