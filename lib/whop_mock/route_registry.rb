# frozen_string_literal: true

module WhopMock
  class RouteRegistry
    RouteEntry = Struct.new(
      :action,
      :method,
      :operation_id,
      :path,
      :resource_name,
      :member_action,
      :request_schema,
      :response_schema,
      keyword_init: true
    )

    HTTP_METHODS = %w[get post put patch delete].freeze

    attr_reader :routes

    def initialize(spec, schema_registry:)
      @spec = spec
      @schema_registry = schema_registry
      @routes = build_routes
    end

    private

    def build_routes
      @spec.fetch("paths", {}).flat_map do |path, operations|
        operations.each_with_object([]) do |(method, operation), routes|
          next unless HTTP_METHODS.include?(method)

          routes << RouteEntry.new(
            action: infer_action(method, path, operation),
            method: method.upcase,
            operation_id: operation["operationId"],
            path: path,
            resource_name: infer_resource_name(path),
            member_action: member_action?(path),
            request_schema: extract_request_schema(operation),
            response_schema: extract_response_schema(operation)
          )
        end
      end
    end

    def extract_request_schema(operation)
      content = operation.fetch("requestBody", {}).fetch("content", {})
      @schema_registry.resolve(content.dig("application/json", "schema"))
    end

    def extract_response_schema(operation)
      content = operation.fetch("responses", {}).fetch("200", {}).fetch("content", {})
      schema = content.dig("application/json", "schema")
      schema ||= operation.fetch("responses", {}).fetch("201", {}).fetch("content", {}).dig("application/json",
                                                                                            "schema")
      @schema_registry.resolve(schema)
    end

    def infer_action(method, path, operation)
      operation_id = operation["operationId"].to_s
      return :search if method == "get" && search_path?(path)
      return :list if method == "get" && collection_path?(path)
      return last_path_segment(path).to_sym if method == "get" && member_action?(path)
      return :retrieve if method == "get"
      return :create if method == "post" && collection_path?(path)
      return last_path_segment(path).to_sym if method == "post" && member_action?(path)
      return :update if %w[patch put].include?(method)
      return :delete if method == "delete"
      return operation_id.sub(/^[a-z]+/, "").downcase.to_sym unless operation_id.empty?

      :custom
    end

    def infer_resource_name(path)
      segment = path.split("/").reject(&:empty?).find { |value| !value.start_with?("{") }
      return if segment.nil?

      if segment.end_with?("ies")
        "#{segment[0...-3]}y"
      else
        segment.sub(/s$/, "")
      end
    end

    def collection_path?(path)
      !path.include?("{")
    end

    def search_path?(path)
      last_path_segment(path) == "search"
    end

    def member_action?(path)
      parts = path.split("/").reject(&:empty?)
      parts.length > 2 && parts[1]&.start_with?("{")
    end

    def last_path_segment(path)
      path.split("/").reject(&:empty?).last
    end
  end
end
