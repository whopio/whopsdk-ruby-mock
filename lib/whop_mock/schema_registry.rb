# frozen_string_literal: true

module WhopMock
  class SchemaRegistry
    def initialize(spec)
      @spec = spec
      @schemas = @spec.fetch("components", {}).fetch("schemas", {})
    end

    def [](name)
      return if name.nil?

      @schemas[name]
    end

    def fetch_ref(ref)
      self[self.class.name_from_ref(ref)]
    end

    def resolve(schema)
      return {} if schema.nil?
      return fetch_ref(schema["$ref"]) if schema["$ref"]

      schema
    end

    def prefix_for(resource_name)
      schema = self[schema_name_for_resource(resource_name)]
      schema&.dig("x-resource-prefix")
    end

    def schema_name_for_resource(resource_name)
      camelize(resource_name)
    end

    def self.name_from_ref(ref)
      ref.split("/").last
    end

    private

    def camelize(value)
      value.to_s.split("_").map(&:capitalize).join
    end
  end
end
