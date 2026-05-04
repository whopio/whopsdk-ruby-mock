# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module Filters
      include ResourceNames

      private

      def filter_records(resource_name, query)
        records = @store.list(resource_name)
        filters = stringify_keys(query.reject { |key, _| pagination_query_key?(key) || ordering_query_key?(key) })

        filters.reduce(records) do |memo, (key, value)|
          apply_filter(resource_name, memo, key, value)
        end
      end

      def apply_filter(resource_name, records, key, value)
        case key.to_s
        when "company_id"
          if ResourceNames.normalize(resource_name) == WEBHOOK
            return records.select do |record|
              field_value(record, "resource_id") == value
            end
          end

          records.select { |record| field_value(record, "company_id") == value }
        when "payment_id"
          records.select { |record| field_value(record, "payment_id") == value }
        when "origin_id"
          records.select { |record| field_value(record, "origin_id") == value }
        when "destination_id"
          records.select { |record| field_value(record, "destination_id") == value }
        when "plan_ids"
          filter_by_any(records, ResourceNames.normalize(resource_name) == PROMO_CODE ? "plan_ids" : "plan_id", value)
        when "product_ids"
          filter_by_any(records, "product_id", value)
        when "user_ids"
          filter_by_any(records, "user_id", value)
        when "user_id"
          records.select { |record| field_value(record, "user_id") == value }
        when "promo_code_ids"
          filter_by_any(records, "promo_code_id", value)
        when "statuses"
          filter_by_any(records, "status", value)
        when "substatuses"
          filter_by_any(records, "substatus", value)
        when "cancel_options"
          filter_by_any(records, "cancel_option", value)
        when "collection_methods"
          filter_by_any(records, "collection_method", value)
        when "billing_reasons"
          filter_by_any(records, "billing_reason", value)
        when "currencies"
          filter_by_any(records, "currency", value)
        when "include_free"
          filter_include_free(records, value)
        when "query"
          filter_by_query(resource_name, records, value)
        when "parent_company_id"
          records.select { |record| field_value(record, "parent_company_id") == value }
        when "visibilities"
          filter_by_any(records, "visibility", value)
        when "product_types"
          filter_by_any(records, "product_type", value)
        when "plan_types"
          filter_by_any(records, "plan_type", value)
        when "release_methods"
          filter_by_any(records, "release_method", value)
        when "most_recent_actions"
          filter_by_any(records, "most_recent_action", value)
        when "created_after"
          filter_by_time(records, "created_at", value, comparator: :>)
        when "created_before"
          filter_by_time(records, "created_at", value, comparator: :<)
        when "updated_after"
          filter_by_time(records, "updated_at", value, comparator: :>)
        when "updated_before"
          filter_by_time(records, "updated_at", value, comparator: :<)
        else
          records.select { |record| field_value(record, key) == value }
        end
      end

      def filter_by_any(records, key, raw_values)
        expected = Array(raw_values).map(&:to_s)
        records.select do |record|
          value = field_value(record, key)
          if value.is_a?(Array)
            value.map(&:to_s).intersect?(expected)
          else
            value && expected.include?(value.to_s)
          end
        end
      end

      def filter_by_time(records, key, raw_value, comparator:)
        boundary = parse_time(raw_value)
        return records unless boundary

        records.select do |record|
          timestamp = parse_time(field_value(record, key))
          timestamp&.public_send(comparator, boundary)
        end
      end

      def filter_include_free(records, value)
        include_free = value.to_s == "true"
        return records if include_free

        records.reject do |record|
          amount = record["total"] || record["subtotal"] || record["amount"] || record["renewal_price"] || record["initial_price"]
          amount.to_f.zero?
        end
      end

      def fee_records(payment_id)
        payment = @store.find("payment", payment_id)
        return [] unless payment

        build_payment_fees(payment)
      end

      def build_payment_fees(payment)
        currency = (payment["currency"] || "usd").to_s
        total = (payment["total"] || payment["subtotal"] || 10.0).to_f
        fees = []

        fees << {
          "id" => "#{payment["id"]}_fee_processing_percentage",
          "amount" => (total * 0.029).round(2),
          "currency" => currency,
          "name" => "Payment processing fee",
          "type" => "payment_processing_percentage_fee"
        }

        fees << {
          "id" => "#{payment["id"]}_fee_processing_fixed",
          "amount" => 0.30,
          "currency" => currency,
          "name" => "Payment processing fixed fee",
          "type" => "payment_processing_fixed_fee"
        }

        if payment["application_fee"] || payment["application_fee_amount"]
          fees << {
            "id" => "#{payment["id"]}_fee_application",
            "amount" => (payment["application_fee"] || payment["application_fee_amount"]).to_f,
            "currency" => currency,
            "name" => "Application fee",
            "type" => "application_fee"
          }
        end

        fees
      end
    end
  end
end
