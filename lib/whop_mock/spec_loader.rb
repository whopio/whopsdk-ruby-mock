# frozen_string_literal: true

require "date"
require "yaml"

module WhopMock
  class SpecLoader
    def initialize(path, debug_io: nil)
      @path = path
      @debug_io = debug_io
    end

    def load
      resolved_path = resolve_path(@path)
      unless resolved_path && File.exist?(resolved_path)
        debug_log("spec file not found: #{@path.inspect}")
        return {}
      end

      debug_log("loading spec from: #{resolved_path}")
      YAML.safe_load_file(resolved_path, permitted_classes: [Date, Time, Symbol], aliases: true) || {}
    end

    def debug_log(message)
      return unless @debug_io

      @debug_io.puts "[WhopMock] #{message}"
    end

    private

    def resolve_path(path)
      case path
      when Array
        path.find { |candidate| candidate && File.exist?(candidate) }
      else
        path
      end
    end
  end
end
