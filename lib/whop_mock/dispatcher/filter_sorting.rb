# frozen_string_literal: true

require "time"

module WhopMock
  class Dispatcher
    module FilterSorting
      include ResourceNames

      private

      def sort_records(resource_name, records, query)
        order = query["order"]&.to_s
        direction = query["direction"]&.to_s
        sort_key = sort_key_for(resource_name, order)
        sorted = records.sort_by { |record| sortable_value(record, sort_key) }
        direction == "asc" ? sorted : sorted.reverse
      end

      def sort_key_for(resource_name, order)
        return "created_at" if order.nil? || order.empty?

        case ResourceNames.normalize(resource_name)
        when "payment_fee"
          "created_at"
        when PAYMENT
          { "final_amount" => "total", "created_at" => "created_at", "paid_at" => "paid_at" }.fetch(order, "created_at")
        when MEMBERSHIP
          {
            "id" => "id",
            "created_at" => "created_at",
            "status" => "status",
            "canceled_at" => "canceled_at"
          }.fetch(order, "created_at")
        when MEMBER
          {
            "id" => "id",
            "created_at" => "created_at",
            "joined_at" => "joined_at",
            "most_recent_action" => "most_recent_action_at",
            "most_recent_action_at" => "most_recent_action_at",
            "status" => "status"
          }.fetch(order, "created_at")
        when INVOICE
          { "id" => "id", "created_at" => "created_at", "due_date" => "due_date" }.fetch(order, "created_at")
        when PRODUCT
          {
            "created_at" => "created_at",
            "active_memberships_count" => "member_count",
            "usd_gmv" => "usd_gmv",
            "usd_gmv_30_days" => "usd_gmv_30_days"
          }.fetch(order, "created_at")
        when PLAN
          {
            "id" => "id",
            "created_at" => "created_at",
            "active_members_count" => "member_count",
            "internal_notes" => "internal_notes",
            "expires_at" => "expires_at"
          }.fetch(order, "created_at")
        when TRANSFER, WITHDRAWAL, PAYOUT_METHOD, CHECKOUT_CONFIGURATION, DISPUTE, DISPUTE_ALERT
          "created_at"
        else
          "created_at"
        end
      end

      def sortable_value(record, key)
        value = field_value(record, key)
        return Time.parse(value).to_i if value.is_a?(String) && time_like?(value)
        return value.downcase if value.is_a?(String)

        value || ""
      rescue ArgumentError
        value || ""
      end

      def ordering_query_key?(key)
        %w[direction order].include?(key.to_s)
      end

      def parse_time(value)
        return value if value.is_a?(Time)
        return nil if blank_value?(value)

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def time_like?(value)
        value.include?("T") || value.include?("UTC")
      end
    end
  end
end
