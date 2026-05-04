# frozen_string_literal: true

module WhopMock
  class ResponseBuilder
    def initialize(store:, schema_registry:)
      @store = store
      @schema_registry = schema_registry
    end

    def build(resource_name:, record:, schema:)
      payload = deep_copy(record)
      hydrate_relations!(payload, schema)
      payload
    end

    private

    def hydrate_relations!(payload, schema)
      resolved_schema = @schema_registry.resolve(schema)
      properties = resolved_schema.fetch("properties", {})

      properties.each do |name, property_schema|
        relation_key = "#{name}_id"
        value = payload[name]
        resolved_property_schema = @schema_registry.resolve(property_schema)

        if payload.key?(relation_key) && relation_target?(value, resolved_property_schema)
          related = @store.find(name, payload[relation_key])
          payload[name] = related unless related.nil?
        elsif payload.key?(name) && foreign_key_field?(name, value)
          resource_name = name.sub(/_id$/, "")
          related = @store.find(resource_name, value)
          payload[resource_name] = related unless related.nil?
        elsif value.is_a?(Hash)
          hydrate_relations!(value, resolved_property_schema)
        elsif value.is_a?(Array) && resolved_property_schema["items"]
          value.each do |item|
            hydrate_relations!(item, resolved_property_schema["items"]) if item.is_a?(Hash)
          end
        end
      end
    end

    def relation_target?(value, schema)
      (value.nil? || value.is_a?(Hash)) && schema["type"] == "object"
    end

    def foreign_key_field?(name, value)
      name.end_with?("_id") && value.is_a?(String)
    end

    def deep_copy(object)
      Marshal.load(Marshal.dump(object))
    end
  end
end
