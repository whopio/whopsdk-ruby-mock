# frozen_string_literal: true

require "json"
require "time"

module WhopMock
  class DebugLogger
    def initialize(enabled:, io:)
      @enabled = enabled
      @io = io
    end

    def request(method:, path:, query:, body:)
      return unless @enabled

      write(
        event: "request",
        method: method.to_s.upcase,
        path: path,
        query: query,
        body: body
      )
    end

    def response(method:, path:, status:, payload:)
      return unless @enabled

      write(
        event: "response",
        method: method.to_s.upcase,
        path: path,
        status: status,
        payload: payload
      )
    end

    def exception(method:, path:, error:)
      return unless @enabled

      write(
        event: "exception",
        method: method.to_s.upcase,
        path: path,
        error_class: error.class.name,
        error_message: error.message
      )
    end

    private

    def write(payload)
      @io.puts("[WhopMock] #{Time.now.utc.iso8601} #{JSON.generate(payload)}")
    end
  end
end
