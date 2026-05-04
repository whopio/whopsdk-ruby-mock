# frozen_string_literal: true

module WhopMock
  class WebhookSimulator
    module WebhookContext
      include ResourceNames

      private

      def hydrate_event_context(resource_name, object)
        case ResourceNames.normalize(resource_name)
        when PAYMENT
          hydrate_payment_context(object)
        when INVOICE
          hydrate_invoice_context(object)
        when MEMBERSHIP
          hydrate_membership_context(object)
        when REFUND
          hydrate_refund_context(object)
        else
          object
        end
      end

      def hydrate_payment_context(object)
        payment = deep_merge(find_record(PAYMENT, object["id"]) || {}, object)
        membership = find_record(MEMBERSHIP, payment["membership_id"]) || payment["membership"]
        invoice = find_record(INVOICE, payment["invoice_id"])
        payment["membership"] ||= compact_hash("id" => membership&.fetch("id", nil),
                                               "status" => membership&.fetch(
                                                 "status", nil
                                               ))
        payment["invoice"] ||= compact_hash("id" => invoice&.fetch("id", nil),
                                            "status" => invoice&.fetch(
                                              "status", nil
                                            ))
        payment
      end

      def hydrate_invoice_context(object)
        invoice = deep_merge(find_record(INVOICE, object["id"]) || {}, object)
        payment = find_record(PAYMENT, invoice["payment_id"])
        invoice["payment"] ||= compact_hash("id" => payment&.fetch("id", nil),
                                            "status" => payment&.fetch("status", nil), "substatus" => payment&.fetch("substatus", nil))
        invoice["membership"] ||= compact_hash("id" => payment&.fetch("membership_id", nil))
        invoice
      end

      def hydrate_membership_context(object)
        membership = deep_merge(find_record(MEMBERSHIP, object["id"]) || {}, object)
        payment = find_record(PAYMENT, membership["payment_id"])
        invoice = find_record(INVOICE, membership["invoice_id"])
        membership["payment"] ||= compact_hash("id" => payment&.fetch("id", nil),
                                               "status" => payment&.fetch("status", nil), "substatus" => payment&.fetch("substatus", nil))
        membership["invoice"] ||= compact_hash("id" => invoice&.fetch("id", nil),
                                               "status" => invoice&.fetch(
                                                 "status", nil
                                               ))
        membership
      end

      def hydrate_refund_context(object)
        refund = deep_merge(find_record(REFUND, object["id"]) || {}, object)
        payment = find_record(PAYMENT, refund.dig("payment", "id"))
        refund["payment"] ||= compact_hash("id" => payment&.fetch("id", nil),
                                           "status" => payment&.fetch("status", nil), "substatus" => payment&.fetch("substatus", nil))
        refund
      end

      def company_id_for_event(event_type, object)
        resource_name = resource_name_for(event_type)
        object["company_id"] ||
          object.dig("company", "id") ||
          find_record(resource_name, object["id"])&.dig("company", "id") ||
          find_record(resource_name, object["id"])&.fetch("company_id", nil) ||
          linked_company_id_for(object)
      end

      def find_record(resource_name, id)
        return nil unless id

        @store.find(resource_name, id)
      end

      def linked_company_id_for(object)
        payment =
          find_record(PAYMENT, object["payment_id"]) ||
          find_record(PAYMENT, object.dig("payment", "id"))
        invoice =
          find_record(INVOICE, object["invoice_id"]) ||
          find_record(INVOICE, object.dig("invoice", "id")) ||
          (payment && find_record(INVOICE, payment["invoice_id"]))

        payment&.dig("company", "id") ||
          payment&.fetch("company_id", nil) ||
          invoice&.dig("company", "id") ||
          invoice&.fetch("company_id", nil)
      end
    end
  end
end
