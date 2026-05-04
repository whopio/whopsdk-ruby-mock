# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module InvoiceGraph
      private

      def ensure_invoice_graph(record, payload)
        company_id = company_id_for(record) || payload["company_id"]
        company = ensure_company_exists(company_id, record["company"])
        payload = resolve_payment_token(payload)

        plan_payload = payload["plan"] || payload["current_plan"] || {}
        plan_source = plan_payload.dup
        if plan_source.empty? && (payload.key?("plan") || payload.key?("current_plan"))
          plan_source["currency"] =
            payload["currency"] || record["currency"] || record.dig("current_plan", "currency") || "usd"
        end
        product_payload = payload["product"] || {}
        product_id = payload["product_id"] || plan_payload["product_id"] || product_payload["id"]

        product = ensure_product_exists(product_id, company_id, product_payload)
        plan = ensure_plan_exists(
          plan_payload["id"],
          company_id: company_id,
          product_id: product&.fetch("id", nil),
          source: plan_source
        )
        timestamps = default_timestamps(record["created_at"])
        user = compact_user(record["user"] || payload["user"], member_id: payload["member_id"] || record["member_id"])

        invoice_updates = invoice_graph_updates(
          record: record,
          payload: payload,
          company: company,
          product: product,
          plan: plan,
          user: user,
          timestamps: timestamps
        )

        @store.update("invoice", record["id"], invoice_updates)
        @store.find("invoice", record["id"]) || record
      end

      def apply_invoice_update_side_effects(_previous, updated, attributes)
        plan_attrs = attributes["plan"]
        return updated unless plan_attrs.is_a?(Hash)

        plan = ensure_plan_exists(
          updated["plan_id"] || updated.dig("current_plan", "id"),
          company_id: company_id_for(updated),
          product_id: updated["product_id"] || updated.dig("product", "id"),
          source: plan_attrs
        )

        updates = {}
        if plan
          updates["plan_id"] = plan["id"]
          updates["plan"] = compact_plan(plan)
          updates["current_plan"] = plan_summary(plan)
        end

        if updated["payment_id"]
          @store.update("payment", updated["payment_id"], compact_hash(
                                                            "plan_id" => plan&.fetch("id", nil),
                                                            "plan" => compact_plan(plan)
                                                          ))
        end

        @store.update("invoice", updated["id"], updates) unless updates.empty?
        @store.find("invoice", updated["id"]) || updated
      end

      def invoice_create_status(record, payload)
        return "draft" if payload["save_as_draft"]
        return "open" if blank_value?(record["status"]) || record["status"] == "active"

        record["status"]
      end
    end
  end
end
