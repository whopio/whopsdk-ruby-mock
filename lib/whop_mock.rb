# frozen_string_literal: true

require "json"
require_relative "whop_mock/version"
require_relative "whop_mock/configuration"
require_relative "whop_mock/session"
require_relative "whop_mock/spec_loader"
require_relative "whop_mock/schema_registry"
require_relative "whop_mock/route_registry"
require_relative "whop_mock/request_matcher"
require_relative "whop_mock/store"
require_relative "whop_mock/id_generator"
require_relative "whop_mock/resource_names"
require_relative "whop_mock/example_generator"
require_relative "whop_mock/fixture_loader"
require_relative "whop_mock/debug_logger"
require_relative "whop_mock/paginator"
require_relative "whop_mock/response_builder"
require_relative "whop_mock/status_transitions"
require_relative "whop_mock/error_mapper"
require_relative "whop_mock/payment_token_store"
require_relative "whop_mock/fallback_registry"
require_relative "whop_mock/dispatcher"
require_relative "whop_mock/mock_requester"
require_relative "whop_mock/error_injector"
require_relative "whop_mock/webhook_defaults"
require_relative "whop_mock/webhook_context"
require_relative "whop_mock/webhook_simulator"
require_relative "whop_mock/client_patcher"
require_relative "whop_mock/http_response"
require_relative "whop_mock/test_helper"

module WhopMock
  class Error < StandardError; end
  NotFoundError = Class.new(Error)

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def session
      Thread.current[:whop_mock_session]
    end

    def start(spec_path: nil)
      spec_path ||= configuration.resolved_spec_path
      session = Session.build(spec_path: spec_path, configuration: configuration)
      Thread.current[:whop_mock_session] = session
      return yield(session) if block_given?

      session
    ensure
      stop if block_given?
    end

    def stop
      Thread.current[:whop_mock_session] = nil
    end

    def requester
      session&.requester
    end

    def install!(client, spec_path: nil)
      spec_path ||= configuration.resolved_spec_path
      session = self.session || start(spec_path: spec_path)
      ClientPatcher.new(client, session.requester).install!
      client
    end

    def uninstall!(client)
      ClientPatcher.new(client, requester).uninstall!
      client
    end

    def prepare_error(error_class, action_key, message: nil, **attributes)
      raise Error, "WhopMock.start must be called before prepare_error" unless session

      session.error_injector.prepare(error_class, action_key, message: message, attributes: attributes)
    end

    def mock_webhook_event(event_type, overrides = {})
      raise Error, "WhopMock.start must be called before mock_webhook_event" unless session

      session.webhook_simulator.mock_webhook_event(event_type, overrides)
    end

    def sign_webhook(payload, secret:, webhook_id: nil, timestamp: Time.now.to_i)
      WebhookSimulator.sign_webhook(payload, secret: secret, webhook_id: webhook_id, timestamp: timestamp)
    end

    def generate_payment_token(**attributes)
      raise Error, "WhopMock.start must be called before generate_payment_token" unless session

      session.payment_token_store.generate(attributes)
    end

    def generate_example(resource_name, overrides = {})
      raise Error, "WhopMock.start must be called before generate_example" unless session

      session.example_generator.generate(resource_name, overrides)
    end

    def seed(resource_name, overrides = {})
      raise Error, "WhopMock.start must be called before seed" unless session

      record = generate_example(resource_name, overrides)
      session.store.insert(resource_name.to_s, record)
    end

    def seed_many(resource_name, rows)
      raise Error, "WhopMock.start must be called before seed_many" unless session

      Array(rows).map { |row| seed(resource_name, row || {}) }
    end

    def load_fixtures(path)
      raise Error, "WhopMock.start must be called before load_fixtures" unless session

      payload = FixtureLoader.new.load(path)
      stringify_fixture_payload(payload).each_with_object({}) do |(resource_name, rows), memo|
        memo[resource_name] = seed_many(resource_name, rows)
      end
    end

    def create_test_helper
      raise Error, "WhopMock.start must be called before create_test_helper" unless session

      TestHelper.new(session)
    end

    def toggle_debug(enabled = true, io: configuration.debug_io)
      configuration.debug = enabled
      configuration.debug_io = io if io
      enabled
    end

    def register_fallback(&)
      raise Error, "WhopMock.start must be called before register_fallback" unless session

      session.fallback_registry.register(&)
    end

    def clear_fallbacks!
      return unless session

      session.fallback_registry.clear
    end

    def search(resource_name, query:, filters: {})
      raise Error, "WhopMock.start must be called before search" unless session

      dispatcher = session.dispatcher
      records = dispatcher.send(:filter_records, resource_name.to_s, filters || {})
      dispatcher.send(:filter_by_query, resource_name.to_s, records, query)
    end

    private

    def stringify_fixture_payload(payload)
      payload.transform_keys(&:to_s)
    end
  end
end
