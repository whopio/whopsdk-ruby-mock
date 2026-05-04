# frozen_string_literal: true

module WhopMock
  class FallbackRegistry
    def initialize
      @handlers = []
      @mutex = Mutex.new
    end

    def register(&block)
      raise ArgumentError, "block required" unless block

      @mutex.synchronize do
        @handlers << block
      end

      block
    end

    def clear
      @mutex.synchronize do
        @handlers.clear
      end
    end

    def call(method:, path:, query:, body:)
      @mutex.synchronize do
        @handlers.reverse_each do |handler|
          result = handler.call(method: method, path: path, query: query, body: body)
          return result unless result.nil?
        end
      end

      nil
    end
  end
end
