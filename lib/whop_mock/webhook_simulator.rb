# frozen_string_literal: true

require "json"
require "openssl"
require "base64"
require "securerandom"
require "time"

module WhopMock
  class WebhookSimulator
    include ResourceNames
    include WebhookDefaults
    include WebhookContext

    RESOURCE_OVERRIDES = {
      "course_lesson_interaction" => "course_lesson_interaction",
      "dispute" => "dispute",
      "dispute_alert" => "dispute_alert",
      "entry" => "entry",
      "membership" => "membership",
      "payment" => "payment",
      "invoice" => "invoice",
      "payout_account" => "payout_account",
      "payout_method" => "payout_method",
      "refund" => "refund",
      "resolution_center_case" => "resolution_center_case",
      "company" => "company",
      "product" => "product",
      "plan" => "plan",
      "setup_intent" => "setup_intent",
      "verification" => "verification",
      "withdrawal" => "withdrawal"
    }.freeze

    STATUS_PROFILES = {
      "membership" => {
        "activated" => { "status" => "active", "payment_collection_paused" => false },
        "updated" => { "status" => "active" },
        "paused" => { "status" => "active", "payment_collection_paused" => true },
        "resumed" => { "status" => "active", "payment_collection_paused" => false },
        "deactivated" => { "status" => "canceled", "payment_collection_paused" => true },
        "canceled" => { "status" => "canceled" },
        "uncanceled" => { "status" => "active", "cancel_at_period_end" => false }
      },
      "payment" => {
        "succeeded" => { "status" => "paid", "substatus" => "succeeded" },
        "failed" => { "status" => "open", "substatus" => "failed" },
        "pending" => { "status" => "pending", "substatus" => "pending" },
        "refunded" => { "status" => "paid", "substatus" => "refunded" },
        "retrying" => { "status" => "pending", "substatus" => "pending" },
        "voided" => { "status" => "void", "substatus" => "canceled" }
      },
      "invoice" => {
        "created" => { "status" => "draft" },
        "updated" => { "status" => "draft" },
        "paid" => { "status" => "paid" },
        "marked_paid" => { "status" => "paid" },
        "marked_uncollectible" => { "status" => "uncollectible" },
        "uncollectible" => { "status" => "uncollectible" },
        "voided" => { "status" => "void" }
      },
      "refund" => {
        "created" => { "status" => "pending" },
        "updated" => { "status" => "succeeded" },
        "succeeded" => { "status" => "succeeded" },
        "failed" => { "status" => "failed" },
        "requires_action" => { "status" => "requires_action" },
        "canceled" => { "status" => "canceled" }
      },
      "setup_intent" => {
        "requires_action" => { "status" => "requires_action" },
        "requires_payment_method" => { "status" => "requires_payment_method" },
        "processing" => { "status" => "processing" },
        "succeeded" => { "status" => "succeeded" },
        "canceled" => { "status" => "canceled" }
      },
      "entry" => {
        "created" => { "status" => "pending" },
        "approved" => { "status" => "approved" },
        "deleted" => { "status" => "denied" },
        "denied" => { "status" => "denied" }
      },
      "course_lesson_interaction" => {
        "completed" => { "completed" => true }
      },
      "payout_account" => {
        "status_updated" => { "status" => "active" },
        "locked" => { "status" => "locked" },
        "deactive" => { "status" => "deactive" },
        "closed" => { "status" => "closed" }
      },
      "payout_method" => {
        "created" => { "is_default" => true }
      },
      "verification" => {
        "created" => { "status" => "created" },
        "started" => { "status" => "started" },
        "requires_input" => { "status" => "requires_input" },
        "processing" => { "status" => "processing" },
        "submitted" => { "status" => "submitted" },
        "succeeded" => { "status" => "verified", "last_error_code" => nil, "last_error_reason" => nil },
        "verified" => { "status" => "verified", "last_error_code" => nil, "last_error_reason" => nil },
        "approved" => { "status" => "approved" },
        "declined" => { "status" => "declined" },
        "canceled" => { "status" => "canceled" },
        "expired" => { "status" => "expired" },
        "abandoned" => { "status" => "abandoned" },
        "review" => { "status" => "review" },
        "action_required" => { "status" => "action_required" },
        "resubmission_requested" => { "status" => "resubmission_requested" }
      },
      "resolution_center_case" => {
        "created" => { "status" => "merchant_response_needed" },
        "updated" => { "status" => "merchant_response_needed" },
        "decided" => { "status" => "merchant_won" }
      },
      "dispute" => {
        "created" => { "status" => "needs_response", "editable" => true },
        "updated" => { "status" => "under_review", "editable" => false },
        "warning_needs_response" => { "status" => "warning_needs_response", "editable" => true },
        "warning_under_review" => { "status" => "warning_under_review", "editable" => false },
        "warning_closed" => { "status" => "warning_closed", "editable" => false },
        "won" => { "status" => "won", "editable" => false },
        "lost" => { "status" => "lost", "editable" => false },
        "closed" => { "status" => "closed", "editable" => false },
        "other" => { "status" => "other" }
      },
      "dispute_alert" => {
        "created" => { "alert_type" => "dispute" }
      },
      "withdrawal" => {
        "created" => { "status" => "requested" },
        "updated" => { "status" => "completed" },
        "awaiting_payment" => { "status" => "awaiting_payment" },
        "completed" => { "status" => "completed" },
        "denied" => { "status" => "denied" },
        "canceled" => { "status" => "canceled" },
        "drafted" => { "status" => "drafted" }
      }
    }.freeze

    def self.sign_webhook(payload, secret:, webhook_id: nil, timestamp: Time.now.to_i)
      # Match backend format: msg_#{SecureRandom.alphanumeric(24)}
      message_id = webhook_id || "msg_#{SecureRandom.alphanumeric(24)}"
      encoded_payload = payload.is_a?(String) ? payload : JSON.generate(payload)

      # Handle both raw secrets and whsec_ formatted secrets
      secret_str = secret.to_s
      if secret_str.start_with?("whsec_")
        # Try to decode as SDK format (whsec_ + base64)
        begin
          raw_secret = Base64.strict_decode64(secret_str.sub("whsec_", ""))
          sdk_secret = secret_str
        rescue ArgumentError
          # Not valid base64 - treat whole string as raw secret
          raw_secret = secret_str
          sdk_secret = "whsec_#{Base64.strict_encode64(secret_str)}"
        end
      else
        # Raw secret - use directly for signing, encode for SDK
        raw_secret = secret_str
        sdk_secret = "whsec_#{Base64.strict_encode64(secret_str)}"
      end

      # Sign with raw secret (matches backend behavior)
      signed_content = "#{message_id}.#{timestamp}.#{encoded_payload}"
      raw_signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", raw_secret, signed_content))
      signature = "v1,#{raw_signature}"

      headers = {
        "webhook-id" => message_id,
        "webhook-timestamp" => timestamp.to_s,
        "webhook-signature" => signature
      }

      {
        "webhook-id" => headers["webhook-id"],
        "webhook-timestamp" => headers["webhook-timestamp"],
        "webhook-signature" => headers["webhook-signature"],
        "headers" => headers,
        "payload" => encoded_payload,
        "body" => encoded_payload,
        "secret" => sdk_secret
      }
    end

    def initialize(example_generator:, id_generator:, store:)
      @example_generator = example_generator
      @id_generator = id_generator
      @store = store
    end

    def mock_webhook_event(event_type, overrides = {})
      object = event_object_for(event_type, overrides)
      event = deep_merge(base_event(event_type, object), stringify_keys(overrides))
      @store.insert("event", event)
    end

    private

    def base_event(event_type, object)
      {
        "id" => @id_generator.generate("event"),
        "api_version" => "v1",
        "type" => event_type.to_s,
        "timestamp" => Time.now.utc.iso8601,
        "created_at" => Time.now.utc.iso8601,
        "company_id" => company_id_for_event(event_type, object),
        "livemode" => false,
        "pending_webhooks" => 0,
        "data" => object
      }
    end

    def event_object_for(event_type, overrides)
      object_overrides = extract_object_overrides(overrides)
      resource_name = resource_name_for(event_type)
      event_defaults = default_attributes_for(resource_name, event_type)

      if object_overrides["id"]
        stored = @store.find(resource_name, object_overrides["id"])
        base_object = if stored
                        deep_merge(stored,
                                   event_defaults)
                      else
                        default_object(resource_name, event_type, object_overrides)
                      end
        hydrate_event_context(resource_name, deep_merge(base_object, object_overrides))
      else
        default_object(resource_name, event_type, object_overrides)
      end
    end

    def default_object(resource_name, event_type, overrides)
      base = default_attributes_for(resource_name, event_type)
      hydrate_event_context(resource_name, @example_generator.generate(resource_name, base.merge(overrides)))
    end

    def extract_object_overrides(overrides)
      data = overrides[:data] || overrides["data"] || {}
      if data.is_a?(Hash) && (data.key?(:object) || data.key?("object"))
        object = data[:object] || data["object"] || {}
        stringify_keys(object)
      else
        stringify_keys(data)
      end
    end

    def stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value.is_a?(Hash) ? stringify_keys(value) : value
      end
    end

    def compact_hash(hash)
      hash.each_with_object({}) do |(key, value), memo|
        memo[key] = value unless value.nil?
      end
    end

    def deep_merge(left, right)
      left.merge(right) do |_key, old_value, new_value|
        if old_value.is_a?(Hash) && new_value.is_a?(Hash)
          deep_merge(old_value, new_value)
        else
          new_value
        end
      end
    end
  end
end
