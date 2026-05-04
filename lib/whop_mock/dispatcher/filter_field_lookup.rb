# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module FilterFieldLookup
      include ResourceNames

      private

      def field_value(record, key)
        key = key.to_s
        return record[key] if record.key?(key)

        case key
        when "company_id" then record["company_id"] || record.dig("company", "id") || linked_payment_company_id(record)
        when "origin_id" then record["origin_id"] || record.dig("origin", "id")
        when "destination_id" then record["destination_id"] || record.dig("destination", "id")
        when "resource_id" then record["resource_id"]
        when "payment_id" then record.dig("payment", "id")
        when "plan_id" then record.dig("plan", "id") || record.dig("current_plan", "id")
        when "product_id" then record.dig("product", "id")
        when "user_id" then record.dig("user", "id") || linked_payment_user_id(record)
        when "promo_code_id" then record.dig("promo_code", "id")
        when "parent_company_id" then record["parent_company_id"]
        end
      end

      def linked_payment_user_id(record)
        payment_id = record.dig("payment", "id")
        payment = payment_id && @store.find(PAYMENT, payment_id)
        payment&.dig("user", "id")
      end

      def linked_payment_company_id(record)
        payment_id = record.dig("payment", "id")
        payment = payment_id && @store.find(PAYMENT, payment_id)
        payment && (payment["company_id"] || payment.dig("company", "id"))
      end
    end
  end
end
