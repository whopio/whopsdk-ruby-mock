# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module PaymentGraph
      private

      def ensure_payment_graph(record, payload)
        company_id = company_id_for(record) || payload["company_id"]
        company = ensure_company_exists(company_id, record["company"])
        payment_method = ensure_payment_method_exists(
          record["payment_method_id"] || payload["payment_method_id"],
          record["payment_method"] || payload["payment_method"]
        )
        plan, product = ensure_payment_plan_graph(record, payload)
        timestamps = default_timestamps(record["created_at"])
        user = compact_user(record["user"] || payload["user"], member_id: payload["member_id"] || record["member_id"])
        member = compact_member(record["member"] || payload["member"],
                                member_id: payload["member_id"] || record["member_id"])

        payment_updates = payment_graph_updates(
          record: record,
          payload: payload,
          company: company,
          payment_method: payment_method,
          plan: plan,
          product: product,
          user: user,
          member: member,
          timestamps: timestamps
        )
        @store.update("payment", record["id"], payment_updates) unless payment_updates.empty?

        payment = @store.find("payment", record["id"]) || record
        payment = ensure_membership_for_payment(payment)
        ensure_invoice_for_payment(payment)
      end

      def ensure_payment_plan_graph(record, payload)
        plan_payload = payload["plan"] || {}
        company_id = company_id_for(record)
        product_payload = plan_payload["product"] || {}
        plan_id = payload["plan_id"] || plan_payload["id"] || record.dig("plan", "id") || record["plan_id"]
        existing_plan = @store.find("plan", plan_id) if plan_id
        product_id = payload["product_id"] || plan_payload["product_id"] || product_payload["id"] || existing_plan&.dig(
          "product", "id"
        ) || existing_plan&.fetch("product_id", nil) || record.dig("product", "id") || record["product_id"]

        product = ensure_product_exists(product_id, company_id, product_payload)
        plan = ensure_plan_exists(plan_id, company_id: company_id, product_id: product&.fetch("id", nil),
                                           source: plan_payload)

        updates = payment_plan_updates(plan: plan, product: product)
        @store.update("payment", record["id"], updates) unless updates.empty?
        [plan, product]
      end

      def ensure_membership_for_payment(payment)
        membership_id = payment["membership_id"] || @id_generator.generate("membership")
        membership = @store.find("membership", membership_id)
        return payment if membership

        membership = membership_graph_attributes(payment: payment, membership_id: membership_id)

        @store.insert("membership", membership)
        @store.update("payment", payment["id"], "membership_id" => membership_id,
                                                "membership" => compact_membership(membership))
        @store.find("payment", payment["id"]) || payment
      end

      def ensure_invoice_for_payment(payment)
        invoice_id = payment["invoice_id"] || @id_generator.generate("invoice")
        invoice = @store.find("invoice", invoice_id)
        return payment if invoice

        invoice = invoice_attributes_for_payment(payment: payment, invoice_id: invoice_id)

        @store.insert("invoice", invoice)
        @store.update("payment", payment["id"], "invoice_id" => invoice_id)
        if payment["membership_id"]
          @store.update("membership", payment["membership_id"], "invoice_id" => invoice_id,
                                                                "payment_id" => payment["id"])
        end
        @store.find("payment", payment["id"]) || payment
      end
    end
  end
end
