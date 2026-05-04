# frozen_string_literal: true

module WhopMock
  class ErrorInjector
    PreparedError = Struct.new(:error_class, :message, :attributes, keyword_init: true)

    def initialize
      @prepared = Hash.new { |hash, key| hash[key] = [] }
    end

    def prepare(error_class, action_key, message:, attributes:)
      @prepared[normalize(action_key)] << PreparedError.new(
        error_class: error_class,
        message: message,
        attributes: attributes
      )
    end

    def raise_if_prepared!(route)
      matched_key(route)&.then do |key|
        prepared_error = @prepared[key].shift
        next unless prepared_error

        if prepared_error.error_class.is_a?(Symbol)
          raise ErrorMapper.build(
            prepared_error.error_class,
            prepared_error.message || default_message(key),
            prepared_error.attributes,
            route: route
          )
        end

        error = prepared_error.error_class.new(prepared_error.message || default_message(key))
        attach_attributes(error, prepared_error.attributes)
        raise error
      end
    end

    private

    def matched_key(route)
      route_keys(route).find { |key| @prepared[key].any? }
    end

    def route_keys(route)
      [
        normalize(route.operation_id),
        normalize("#{route.action}_#{route.resource_name}"),
        normalize("#{route.resource_name}.#{route.action}")
      ].compact
    end

    def normalize(value)
      value.to_s.strip.downcase
    end

    def default_message(key)
      "Prepared error for #{key}"
    end

    def attach_attributes(error, attributes)
      attributes.each do |name, value|
        error.instance_variable_set(:"@#{name}", value)
        define_reader(error, name)
      end
    end

    def define_reader(error, name)
      singleton_class = class << error; self; end
      singleton_class.send(:attr_reader, name) unless error.respond_to?(name)
    end
  end
end
