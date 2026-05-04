# frozen_string_literal: true

require "time"

module WhopMock
  class PaymentTokenStore
    DEFAULT_ATTRIBUTES = {
      "brand" => "visa",
      "country" => "US",
      "exp_month" => 1,
      "exp_year" => 2030,
      "last4" => "4242"
    }.freeze

    def initialize(id_generator:, store:)
      @id_generator = id_generator
      @store = store
    end

    def generate(attributes = {})
      token = DEFAULT_ATTRIBUTES.merge(stringify_keys(attributes)).merge(
        "id" => @id_generator.generate("payment_token"),
        "type" => "payment_token",
        "created_at" => Time.now.utc.iso8601
      )
      @store.insert("payment_token", token)
    end

    def find(id)
      @store.find("payment_token", id)
    end

    private

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
