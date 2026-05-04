# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module LifecycleSync
      private

      def apply_payment_refund_side_effect(previous, updated, attributes)
        requested_amount = attributes["partial_amount"] || attributes["amount"] || previous["total"] || previous["subtotal"] || 10.0
        amount = effective_refund_amount(requested_amount, previous)
        prior_refunded_amount = (previous["refunded_amount"] || 0).to_f
        total_refunded_amount = prior_refunded_amount + amount.to_f
        partial = partial_refund_total?(total_refunded_amount, previous)
        refund = @example_generator.generate("refund", {
                                               "amount" => amount,
                                               "created_at" => Time.now.utc.iso8601,
                                               "currency" => previous["currency"] || "usd",
                                               "payment" => { "id" => previous["id"] },
                                               "status" => "succeeded"
                                             })

        @store.insert("refund", refund)
        payment_updates = {
          "refunded_amount" => total_refunded_amount,
          "refunded_at" => Time.now.utc.iso8601,
          "tax_refunded_amount" => if previous["tax_amount"]
                                     [previous["tax_amount"].to_f,
                                      total_refunded_amount].min
                                   else
                                     previous["tax_refunded_amount"]
                                   end,
          "refundable" => refundable_after_refund?(total_refunded_amount, previous)
        }
        payment_updates["substatus"] = partial ? "partially_refunded" : "refunded"

        payment = @store.update("payment", updated["id"], payment_updates) || updated
        sync_invoice_status(payment, partial ? "paid" : "refunded")
        cancel_membership_for(payment) unless partial
        payment
      end

      def sync_invoice_status(payment, status)
        invoice_id = payment["invoice_id"]
        return unless invoice_id

        @store.update("invoice", invoice_id, "status" => status)
      end

      def sync_payment_status(invoice, status, substatus)
        payment_id = invoice["payment_id"]
        return unless payment_id

        @store.update("payment", payment_id, "status" => status, "substatus" => substatus)
      end

      def activate_membership_for(record)
        membership_id = record["membership_id"]
        membership_id ||= linked_payment_membership_id(record["payment_id"]) if record["payment_id"]
        return unless membership_id

        @store.update("membership", membership_id, {
                        "status" => "active",
                        "payment_collection_paused" => false,
                        "canceled_at" => nil,
                        "cancel_at_period_end" => false
                      })
      end

      def cancel_membership_for(record)
        membership_id = record["membership_id"]
        membership_id ||= linked_payment_membership_id(record["payment_id"]) if record["payment_id"]
        return unless membership_id

        @store.update("membership", membership_id, {
                        "status" => "canceled",
                        "canceled_at" => Time.now.utc.iso8601,
                        "payment_collection_paused" => true
                      })
      end

      def pause_membership_for(record)
        membership_id = record["membership_id"]
        membership_id ||= linked_payment_membership_id(record["payment_id"]) if record["payment_id"]
        return unless membership_id

        @store.update("membership", membership_id, {
                        "payment_collection_paused" => true
                      })
      end

      def linked_payment_membership_id(payment_id)
        payment = @store.find("payment", payment_id)
        payment && payment["membership_id"]
      end

      def invoice_status_for_payment(payment)
        case payment["status"]
        when "paid" then "paid"
        when "void" then "void"
        else "open"
        end
      end

      def partial_refund_total?(refunded_amount, payment)
        total = payment["total"] || payment["subtotal"]
        return false if total.nil?

        refunded_amount.to_f < total.to_f
      end

      def effective_refund_amount(amount, payment)
        total = payment["total"] || payment["subtotal"]
        return amount unless total

        remaining = total.to_f - (payment["refunded_amount"] || 0).to_f
        [amount.to_f, remaining].min
      end

      def refundable_after_refund?(refunded_amount, payment)
        total = (payment["total"] || payment["subtotal"]).to_f
        refunded_amount.to_f < total
      end

      def billing_default_status?(value)
        blank_value?(value) || %w[active open pending].include?(value)
      end
    end
  end
end
