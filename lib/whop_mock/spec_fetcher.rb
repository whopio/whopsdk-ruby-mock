# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"
require "tmpdir"

module WhopMock
  class SpecFetcher
    STAINLESS_URL = "https://app.stainless.com/api/spec/documented/whopsdk/openapi.documented.yml"
    CACHE_DIR = File.join(Dir.tmpdir, "whop_mock_cache")
    CACHE_FILE = "openapi.yml"
    CACHE_TTL = 86_400 # 24 hours

    def initialize(url: STAINLESS_URL, cache_dir: CACHE_DIR, ttl: CACHE_TTL, debug_io: nil)
      @url = url
      @cache_dir = cache_dir
      @ttl = ttl
      @debug_io = debug_io
    end

    def fetch
      cached = cached_spec_path
      return cached if cached && cache_fresh?

      fetched = fetch_from_remote
      return fetched if fetched

      # Fall back to stale cache if fetch fails
      return cached if cached && File.exist?(cached)

      nil
    end

    def cache_path
      File.join(@cache_dir, CACHE_FILE)
    end

    def clear_cache
      FileUtils.rm_f(cache_path)
    end

    private

    def cached_spec_path
      path = cache_path
      File.exist?(path) ? path : nil
    end

    def cache_fresh?
      return false unless File.exist?(cache_path)

      age = Time.now - File.mtime(cache_path)
      fresh = age < @ttl
      debug_log("cache age: #{age.to_i}s, ttl: #{@ttl}s, fresh: #{fresh}")
      fresh
    end

    def fetch_from_remote
      debug_log("fetching spec from #{@url}")

      uri = URI.parse(@url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      response = http.get(uri.request_uri)

      unless response.is_a?(Net::HTTPSuccess)
        debug_log("fetch failed: #{response.code} #{response.message}")
        return nil
      end

      FileUtils.mkdir_p(@cache_dir)
      File.write(cache_path, response.body)
      debug_log("cached spec to #{cache_path} (#{response.body.bytesize} bytes)")

      cache_path
    rescue StandardError => e
      debug_log("fetch error: #{e.message}")
      nil
    end

    def debug_log(message)
      return unless @debug_io

      @debug_io.puts "[WhopMock::SpecFetcher] #{message}"
    end
  end
end
