# frozen_string_literal: true

require "json"
require "yaml"

module WhopMock
  class FixtureLoader
    def initialize
      @seeders = {
        ".json" => ->(content) { JSON.parse(content) },
        ".yml" => ->(content) { YAML.safe_load(content, aliases: true) },
        ".yaml" => ->(content) { YAML.safe_load(content, aliases: true) }
      }
    end

    def load(path)
      extension = File.extname(path.to_s).downcase
      parser = @seeders.fetch(extension) do
        raise Error, "Unsupported fixture format for #{path}"
      end

      parser.call(File.read(path))
    end
  end
end
