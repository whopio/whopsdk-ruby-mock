# frozen_string_literal: true

module WhopMock
  class RequestMatcher
    Match = Struct.new(:route, :path_params, keyword_init: true)

    def initialize(route_registry)
      @route_registry = route_registry
    end

    def match(method, path)
      normalized_path = normalize_path(path)

      @route_registry.routes.each do |route|
        path_params = match_path(route.path, normalized_path)
        next unless path_params
        next unless route.method == method.to_s.upcase

        return Match.new(route: route, path_params: path_params)
      end

      nil
    end

    private

    def normalize_path(path)
      path.to_s.split("?").first
    end

    def match_path(template, actual)
      template_parts = template.split("/").reject(&:empty?)
      actual_parts = actual.split("/").reject(&:empty?)
      return nil unless template_parts.length == actual_parts.length

      template_parts.zip(actual_parts).each_with_object({}) do |(template_part, actual_part), params|
        if template_part.start_with?("{") && template_part.end_with?("}")
          params[template_part.delete("{}")] = actual_part
        elsif template_part != actual_part
          return nil
        end
      end
    end
  end
end
