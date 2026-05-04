# frozen_string_literal: true

require "time"

module WhopMock
  class ExampleGenerator
    FALLBACKS = {
      "payment_token" => {
        "brand" => "visa",
        "country" => "US",
        "exp_month" => 12,
        "exp_year" => 35,
        "last4" => "4242",
        "type" => "payment_token"
      }
    }.freeze

    # Resource-specific status defaults (backend-accurate)
    RESOURCE_STATUS_DEFAULTS = {
      "withdrawal" => "requested",
      "invoice" => "draft",
      "payment" => "pending",
      "refund" => "pending",
      "entry" => "pending",
      "verification" => "created",
      "dispute" => "needs_response",
      "setup_intent" => "requires_payment_method"
    }.freeze

    NAME_DEFAULTS = {
      "status" => "active", # fallback for resources not in RESOURCE_STATUS_DEFAULTS
      "payment_method_type" => "card",
      "typename" => "BasePaymentMethod",
      "username" => "example-user",
      "email" => "user@example.com",
      "email_address" => "customer@example.com",
      "route" => "example-route",
      "title" => "Example",
      "name" => "Example",
      "description" => "Example description",
      "fetch_invoice_token" => "invoice_token_example",
      "number" => "INV-001",
      "currency" => "usd",
      "base_currency" => "usd",
      "country" => "US",
      "phone" => "+1-555-123-4567",
      "phone_number" => "+1-555-123-4567",
      "statement_descriptor" => "WHOP*EXAMPLE",
      "code" => "PROMO2024",
      "secret" => "whsec_test_secret",
      "payer_name" => "Example Payer"
    }.freeze

    URL_FIELDS = %w[
      url refresh_url return_url callback_url redirect_url success_url cancel_url
      webhook_url image_url logo_url avatar_url checkout_url portal_url manage_url
    ].freeze

    def initialize(id_generator:, schema_registry:)
      @id_generator = id_generator
      @schema_registry = schema_registry
    end

    def generate(resource_name, overrides = {})
      schema = @schema_registry[@schema_registry.schema_name_for_resource(resource_name)] || {}
      base =
        if schema.empty?
          fallback_example(resource_name)
        else
          generate_from_schema(schema, resource_name: resource_name, property_name: nil)
        end
      deep_merge(base, stringify_keys(overrides))
    end

    private

    def generate_from_schema(schema, resource_name:, property_name:)
      resolved = @schema_registry.resolve(schema)
      return {} if resolved.nil? || resolved.empty?

      case resolved["type"]
      when "object", nil
        generate_object(resolved, resource_name: resource_name)
      when "array"
        []
      when "boolean"
        false
      when "integer"
        integer_default(property_name)
      when "number"
        10.0
      when "string"
        string_default(resolved, resource_name: resource_name, property_name: property_name)
      end
    end

    def generate_object(schema, resource_name:)
      properties = schema.fetch("properties", {})
      properties.each_with_object({}) do |(name, property_schema), memo|
        memo[name] = generate_property(name, property_schema, resource_name: resource_name)
      end
    end

    def generate_property(name, property_schema, resource_name:)
      resolved = @schema_registry.resolve(property_schema)

      if name == "id"
        @id_generator.generate(resource_name)
      elsif name.end_with?("_id")
        @id_generator.generate(name.delete_suffix("_id"))
      elsif name == "status" && RESOURCE_STATUS_DEFAULTS.key?(resource_name)
        # Use resource-specific default status
        RESOURCE_STATUS_DEFAULTS[resource_name]
      elsif resolved["enum"].is_a?(Array) && !resolved["enum"].empty?
        resolved["enum"].first
      else
        generate_from_schema(resolved, resource_name: nested_resource_name(name, resource_name), property_name: name)
      end
    end

    def string_default(schema, resource_name:, property_name:)
      return schema["enum"].first if schema["enum"].is_a?(Array) && !schema["enum"].empty?

      prop_str = property_name.to_s

      # Handle URLs by format or field name
      return "https://example.com/#{prop_str.delete_suffix("_url")}" if schema["format"] == "uri" || URL_FIELDS.include?(prop_str) || prop_str.end_with?("_url")

      case prop_str
      when "id"
        @id_generator.generate(resource_name)
      when /_at\z/, /\A(created_at|updated_at|due_date|expires_at|joined_at)\z/
        Time.now.utc.iso8601
      when /amount/, /price/, /total/, /subtotal/, /fee/
        "10.00"
      else
        NAME_DEFAULTS.fetch(prop_str, "#{property_name || resource_name}_example")
      end
    end

    def integer_default(property_name)
      case property_name.to_s
      when /exp_month/ then 12
      when /exp_year/ then 35
      else 1
      end
    end

    def nested_resource_name(name, fallback)
      singular = if name.to_s.end_with?("ies")
                   "#{name.to_s[0...-3]}y"
                 else
                   name.to_s.sub(/s\z/, "")
                 end
      @schema_registry[@schema_registry.schema_name_for_resource(singular)] ? singular : fallback
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

    def deep_merge(left, right)
      left.merge(right) do |_key, old_value, new_value|
        if old_value.is_a?(Hash) && new_value.is_a?(Hash)
          deep_merge(old_value, new_value)
        else
          new_value
        end
      end
    end

    def fallback_example(resource_name)
      { "id" => @id_generator.generate(resource_name) }.merge(FALLBACKS.fetch(resource_name.to_s, {}))
    end
  end
end
