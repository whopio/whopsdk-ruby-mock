# frozen_string_literal: true

require "securerandom"

module WhopMock
  class IdGenerator
    DEFAULT_PREFIXES = {
      "event" => "evt_",
      "payment_token" => "tok_"
    }.freeze

    def initialize(schema_registry:, overrides: {})
      @schema_registry = schema_registry
      @overrides = overrides
    end

    def generate(resource_name)
      prefix = @overrides[resource_name.to_s] || @schema_registry.prefix_for(resource_name) || DEFAULT_PREFIXES[resource_name.to_s] || "#{resource_name.to_s[0,
                                                                                                                                                             3]}_"
      "#{prefix}#{SecureRandom.alphanumeric(12).downcase}"
    end
  end
end
