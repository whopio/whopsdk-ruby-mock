# frozen_string_literal: true

require "uri"

module WhopMock
  class MockRequester
    def initialize(dispatcher:, configuration:, debug_logger:, fallback_registry:)
      @dispatcher = dispatcher
      @configuration = configuration
      @debug_logger = debug_logger
      @fallback_registry = fallback_registry
    end

    def execute(input)
      method = fetch_value(input, :method) || fetch_value(input, "method")
      url = fetch_value(input, :url) || fetch_value(input, "url")
      path = fetch_value(input, :path) || fetch_value(input, "path")
      body = normalize_body(fetch_value(input, :body) || fetch_value(input, "body"))

      parsed_url = parse_url(url || path)
      query = parse_query(parsed_url)
      normalized_path = normalize_path(parsed_url.path)

      @debug_logger.request(method: method, path: normalized_path, query: query, body: body)

      status, payload =
        @dispatcher.dispatch(method: method, path: normalized_path, query: query, body: body)
      @debug_logger.response(method: method, path: normalized_path, status: status, payload: payload)
      response_body = JSON.generate(payload)
      response = HTTPResponse.new(status: status, body: response_body,
                                  headers: { "content-type" => "application/json" })
      [status, response, [response_body]]
    rescue NotFoundError => e
      @debug_logger.exception(method: method, path: normalized_path || "/", error: e)
      error_response(404, e.message)
    rescue Error => e
      fallback = @fallback_registry.call(method: method, path: normalized_path, query: query, body: body)
      raise e if fallback.nil?

      status, payload = normalize_fallback(fallback)
      @debug_logger.response(method: method, path: normalized_path, status: status, payload: payload)
      response_body = JSON.generate(payload)
      response = HTTPResponse.new(status: status, body: response_body,
                                  headers: { "content-type" => "application/json" })
      [status, response, [response_body]]
    rescue StandardError => e
      @debug_logger.exception(method: method, path: normalized_path || "/", error: e)
      raise
    end

    private

    def error_response(status, message)
      payload = { "error" => message }
      response_body = JSON.generate(payload)
      response = HTTPResponse.new(status: status, body: response_body,
                                  headers: { "content-type" => "application/json" })
      [status, response, [response_body]]
    end

    def normalize_fallback(fallback)
      if fallback.is_a?(Array) && fallback.length == 2
        [fallback[0].to_i, fallback[1]]
      else
        [200, fallback]
      end
    end

    def normalize_body(body)
      return nil if body.nil?
      return JSON.parse(body) if body.is_a?(String) && json_payload?(body)

      body
    rescue JSON::ParserError
      body
    end

    def json_payload?(body)
      stripped = body.strip
      stripped.start_with?("{", "[")
    end

    def parse_url(value)
      uri = value.is_a?(URI::Generic) ? value : URI.parse(value.to_s)
      return uri if uri.path && !uri.path.empty?

      URI.parse("/")
    rescue URI::InvalidURIError
      URI.parse("/")
    end

    def parse_query(uri)
      URI.decode_www_form(uri.query.to_s).each_with_object({}) do |(key, value), memo|
        normalized_key = key.to_s.delete_suffix("[]")
        memo[normalized_key] = if memo.key?(normalized_key)
                                 Array(memo[normalized_key]) << value
                               else
                                 key.to_s.end_with?("[]") ? [value] : value
                               end
      end
    end

    def normalize_path(path)
      base_path = @configuration.api_base_path.to_s
      return path if base_path.empty? || base_path == "/"
      return "/" if path == base_path
      return path.delete_prefix(base_path) if path.start_with?(base_path)

      path
    end

    def fetch_value(input, key)
      if input.respond_to?(:[])
        input[key]
      elsif input.respond_to?(key)
        input.public_send(key)
      end
    end
  end
end
