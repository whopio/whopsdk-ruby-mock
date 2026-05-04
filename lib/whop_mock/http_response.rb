# frozen_string_literal: true

require "net/http"

module WhopMock
  class HTTPResponse
    attr_reader :body, :code, :message

    def initialize(status:, body:, headers: {})
      @status = Integer(status)
      @body = body
      @headers = headers.transform_keys { |key| key.to_s.downcase }
      @code = @status.to_s
      @message = default_message(@status)
    end

    def [](header_name)
      @headers[header_name.to_s.downcase]
    end

    def each_header(&block)
      return enum_for(:each_header) unless block

      @headers.each(&block)
    end

    def to_hash
      @headers.transform_values { |value| Array(value) }
    end

    def is_a?(klass)
      return true if klass == Net::HTTPResponse

      super
    end

    alias kind_of? is_a?

    private

    def default_message(status)
      case status
      when 200 then "OK"
      when 201 then "Created"
      when 400 then "Bad Request"
      when 401 then "Unauthorized"
      when 403 then "Forbidden"
      when 404 then "Not Found"
      when 409 then "Conflict"
      when 422 then "Unprocessable Entity"
      when 429 then "Too Many Requests"
      else "Mock Response"
      end
    end
  end
end
