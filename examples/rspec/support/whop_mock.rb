# frozen_string_literal: true

require "whop_mock"
require "whop_sdk"

RSpec.configure do |config|
  config.before(:each) do
    WhopMock.configure do |mock|
      mock.spec_path = ENV.fetch("WHOP_MOCK_SPEC_PATH",
                                 File.expand_path("../../../../spec/fixtures/openapi.yml", __dir__))
    end

    WhopMock.start
  end

  config.after(:each) do
    WhopMock.stop
  end
end

def build_whop_client(**overrides)
  defaults = {
    api_key: "Bearer test_key",
    max_retries: 0,
    base_url: "https://api.whop.com/api/v1"
  }

  client = WhopSDK::Client.new(**defaults, **overrides)
  WhopMock.install!(client)
  client
end
