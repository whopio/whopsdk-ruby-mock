# frozen_string_literal: true

require "time"

module WhopMock
  class StatusTransitions
    DEFAULT_RULES = {
      "membership" => {
        "cancel" => { "status" => "canceled", "canceled_at" => -> { Time.now.utc.iso8601 } },
        "activate" => { "status" => "active" },
        "pause" => { "payment_collection_paused" => true },
        "resume" => { "status" => "active", "payment_collection_paused" => false },
        "uncancel" => { "status" => "active", "canceled_at" => nil, "cancel_at_period_end" => false },
        "add_free_days" => lambda do |record|
          free_days = Integer(record.fetch("_action_attributes", {}).fetch("free_days", 0))
          current_end =
            begin
              Time.parse(record["renewal_period_end"].to_s)
            rescue ArgumentError
              Time.now.utc
            end
          {
            "renewal_period_end" => (current_end + (free_days * 86_400)).iso8601
          }
        end
      },
      "payment" => {
        "refund" => {
          "status" => "paid",
          "substatus" => "refunded",
          "refundable" => false,
          "refunded_at" => -> { Time.now.utc.iso8601 }
        },
        "void" => { "status" => "void", "substatus" => "canceled", "voidable" => false },
        "retry" => {
          "status" => "pending",
          "substatus" => "pending",
          "failure_message" => nil,
          "last_payment_attempt" => -> { Time.now.utc.iso8601 }
        }
      },
      "invoice" => {
        "mark_paid" => { "status" => "paid" },
        "mark_uncollectible" => { "status" => "uncollectible" },
        "void" => { "status" => "void" }
      },
      "dispute" => {
        "submit_evidence" => lambda do |record|
          current = record["status"].to_s
          next_status = current.start_with?("warning_") ? "warning_under_review" : "under_review"
          {
            "editable" => false,
            "status" => next_status
          }
        end,
        "update_evidence" => {}
      }
    }.freeze

    def initialize(rules: DEFAULT_RULES)
      @rules = rules
    end

    def apply(resource_name:, action:, record:, attributes: {})
      updates = resolved_updates(resource_name, action, record)
      return stringify_keys(attributes) if updates.empty?

      updates.merge(stringify_keys(attributes))
    end

    private

    def resolved_updates(resource_name, action, record)
      rule = @rules.fetch(resource_name.to_s, {})[action.to_s] || {}
      return rule.call(record) if rule.respond_to?(:call)

      rule.transform_values do |value|
        if value.respond_to?(:call)
          value.arity.zero? ? value.call : value.call(record)
        else
          value
        end
      end
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
