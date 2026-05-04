# frozen_string_literal: true

require_relative "spec_fetcher"

module WhopMock
  class Configuration
    attr_accessor :api_base_path, :debug, :debug_io, :id_prefixes, :spec_path, :auto_fetch_spec

    def initialize
      @api_base_path = "/api/v1"
      @debug = false
      @debug_io = $stdout
      @spec_path = nil
      @auto_fetch_spec = true
      @id_prefixes = {}
    end

    def resolved_spec_path
      # 1. Explicit user-provided path
      return spec_path if spec_path && File.exist?(spec_path)

      # 2. Auto-fetch from Stainless (cached)
      if auto_fetch_spec
        fetcher = SpecFetcher.new(debug_io: debug ? debug_io : nil)
        fetched = fetcher.fetch
        return fetched if fetched
      end

      # 3. Fallback to bundled placeholder
      bundled_spec_path
    end

    def bundled_spec_path
      File.expand_path("../data/openapi.yml", __dir__)
    end
  end
end
