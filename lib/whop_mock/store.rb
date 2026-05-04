# frozen_string_literal: true

module WhopMock
  class Store
    def initialize
      @data = Hash.new { |hash, key| hash[key] = {} }
      @mutex = Mutex.new
    end

    def insert(resource_name, attributes)
      record = deep_copy(attributes)

      @mutex.synchronize do
        @data[resource_name][record.fetch("id")] = record
      end

      deep_copy(record)
    end

    def find(resource_name, id)
      @mutex.synchronize do
        deep_copy(@data.dig(resource_name, id))
      end
    end

    def update(resource_name, id, attributes)
      @mutex.synchronize do
        current = @data.dig(resource_name, id)
        return nil unless current

        current.merge!(deep_copy(attributes))
        deep_copy(current)
      end
    end

    def delete(resource_name, id)
      @mutex.synchronize do
        deep_copy(@data.fetch(resource_name, {}).delete(id))
      end
    end

    def list(resource_name, filters = {})
      @mutex.synchronize do
        @data.fetch(resource_name, {}).values.filter do |record|
          filters.all? { |key, value| record[key.to_s] == value }
        end.map { |record| deep_copy(record) }
      end
    end

    def search(resource_name, query:, &block)
      needle = query.to_s.downcase

      @mutex.synchronize do
        @data.fetch(resource_name, {}).values.filter do |record|
          next true if needle.empty?
          next block.call(deep_copy(record), needle) if block

          deep_search?(record, needle)
        end.map { |record| deep_copy(record) }
      end
    end

    private

    def deep_copy(object)
      Marshal.load(Marshal.dump(object))
    end

    def deep_search?(value, needle)
      case value
      when Hash
        value.values.any? { |child| deep_search?(child, needle) }
      when Array
        value.any? { |child| deep_search?(child, needle) }
      when nil
        false
      else
        value.to_s.downcase.include?(needle)
      end
    end
  end
end
