# frozen_string_literal: true

require "uri"

module WhopMock
  class ErrorMapper
    FALLBACKS = {
      api_error: "WhopMock::Error",
      api_connection: "WhopMock::Error",
      timeout: "WhopMock::Error",
      bad_request: "WhopMock::Error",
      authentication: "WhopMock::Error",
      permission_denied: "WhopMock::Error",
      not_found: "WhopMock::NotFoundError",
      conflict: "WhopMock::Error",
      unprocessable_entity: "WhopMock::Error",
      rate_limit: "WhopMock::Error",
      internal_server: "WhopMock::Error"
    }.freeze

    SDK_MAP = {
      api_error: "WhopSDK::Errors::APIError",
      api_connection: "WhopSDK::Errors::APIConnectionError",
      timeout: "WhopSDK::Errors::APITimeoutError",
      bad_request: "WhopSDK::Errors::BadRequestError",
      authentication: "WhopSDK::Errors::AuthenticationError",
      permission_denied: "WhopSDK::Errors::PermissionDeniedError",
      not_found: "WhopSDK::Errors::NotFoundError",
      conflict: "WhopSDK::Errors::ConflictError",
      unprocessable_entity: "WhopSDK::Errors::UnprocessableEntityError",
      rate_limit: "WhopSDK::Errors::RateLimitError",
      internal_server: "WhopSDK::Errors::InternalServerError"
    }.freeze

    STATUS_CODES = {
      bad_request: 400,
      authentication: 401,
      permission_denied: 403,
      not_found: 404,
      conflict: 409,
      unprocessable_entity: 422,
      rate_limit: 429,
      internal_server: 500
    }.freeze

    def self.build(error_key, message, attributes = {}, route: nil)
      error = build_error(error_key, message, attributes, route: route)
      attributes.each do |name, value|
        error.instance_variable_set(:"@#{name}", value)
        singleton_class = class << error; self; end
        singleton_class.send(:attr_reader, name) unless error.respond_to?(name)
      end
      error
    end

    def self.resolve(error_key)
      constantize(SDK_MAP[error_key]) || constantize(FALLBACKS.fetch(error_key))
    end

    def self.build_error(error_key, message, attributes, route:)
      return build_sdk_error(error_key, message, attributes, route: route) if sdk_error?(error_key)

      resolve(error_key).new(message)
    end

    def self.build_sdk_error(error_key, message, attributes, route:)
      raw_url = attributes[:url] || attributes["url"] || "https://api.whop.com/api/v1#{route&.path || "/"}"
      url = URI.parse(raw_url.to_s.gsub(/\{[^}]+\}/, "test"))
      headers = attributes[:headers] || attributes["headers"] || { "content-type" => "application/json" }
      body = attributes[:body] || attributes["body"] || { "error" => message }
      status = attributes[:status] || attributes["status"] || STATUS_CODES[error_key]

      case error_key.to_sym
      when :api_error
        resolve(error_key).new(url: url, status: status, headers: headers, body: body, request: nil, response: nil,
                               message: message)
      when :api_connection, :timeout
        resolve(error_key).new(url: url, headers: headers, request: nil, response: nil, message: message)
      else
        resolve(error_key).new(url: url, status: status, headers: headers, body: body, request: nil, response: nil,
                               message: message)
      end
    end

    def self.sdk_error?(error_key)
      SDK_MAP.key?(error_key.to_sym) && constantize(SDK_MAP[error_key.to_sym])
    end

    def self.constantize(name)
      return nil unless name

      name.split("::").reject(&:empty?).inject(Object) { |scope, constant| scope.const_get(constant) }
    rescue NameError
      nil
    end
  end
end
