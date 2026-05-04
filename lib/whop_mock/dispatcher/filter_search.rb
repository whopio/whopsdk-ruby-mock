# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module FilterSearch
      include ResourceNames

      private

      def filter_by_query(resource_name, records, value)
        needle = value.to_s.downcase
        return records if needle.empty?

        case ResourceNames.normalize(resource_name)
        when PAYMENT
          records.select { |record| record_search_values(record).any? { |item| item.to_s.downcase.include?(needle) } }
        when INVOICE
          records.select { |record| invoice_search_values(record).any? { |item| item.to_s.downcase.include?(needle) } }
        when MEMBERSHIP
          records.select do |record|
            membership_search_values(record).any? do |item|
              item.to_s.downcase.include?(needle)
            end
          end
        when MEMBER
          records.select { |record| member_search_values(record).any? { |item| item.to_s.downcase.include?(needle) } }
        else
          records.select do |record|
            flatten_metadata_values(record).any? { |item| item.to_s.downcase.include?(needle) }
          end
        end
      end

      def record_search_values(record)
        [
          record["id"],
          record["membership_id"],
          record.dig("membership", "id"),
          record.dig("user", "id"),
          record.dig("user", "email"),
          record.dig("user", "name"),
          record.dig("user", "username"),
          record.dig("payment_method", "id"),
          record.dig("payment_method", "brand"),
          record.dig("payment_method", "last4"),
          *flatten_metadata_values(record["metadata"])
        ].compact
      end

      def invoice_search_values(record)
        [
          record["id"],
          record["email_address"],
          record["customer_name"],
          record["member_id"],
          record.dig("user", "id"),
          record.dig("user", "email"),
          record.dig("user", "name"),
          record.dig("user", "username"),
          record.dig("current_plan", "id"),
          record["plan_id"],
          record["product_id"]
        ].compact
      end

      def membership_search_values(record)
        [
          record["id"],
          record["member_id"],
          record.dig("user", "id"),
          record.dig("user", "email"),
          record.dig("user", "name"),
          record.dig("user", "username"),
          record["plan_id"],
          record["product_id"]
        ].compact
      end

      def member_search_values(record)
        [
          record["id"],
          record.dig("user", "id"),
          record.dig("user", "email"),
          record.dig("user", "name"),
          record.dig("user", "username")
        ].compact
      end

      def flatten_metadata_values(metadata)
        case metadata
        when Hash
          metadata.values.flat_map { |value| flatten_metadata_values(value) }
        when Array
          metadata.flat_map { |value| flatten_metadata_values(value) }
        when nil
          []
        else
          [metadata]
        end
      end
    end
  end
end
