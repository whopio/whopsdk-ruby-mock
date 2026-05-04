# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module GraphPayloads
      private

      def payment_graph_updates(record:, payload:, company:, payment_method:, plan:, product:, user:, member:,
                                timestamps:)
        total = record["total"] || payload["amount"] || plan_price(plan) || 10.0

        compact_hash(
          "company_id" => company_id_for(record) || payload["company_id"],
          "company" => compact_company(company),
          "currency" => payload["currency"] || plan&.fetch("currency", nil) || record["currency"] || "usd",
          "created_at" => record["created_at"] || timestamps["created_at"],
          "updated_at" => timestamps["updated_at"],
          "paid_at" => record["paid_at"] || timestamps["created_at"],
          "member_id" => payload["member_id"] || record["member_id"] || member&.fetch("id", nil),
          "member" => member,
          "user" => user,
          "payment_method_id" => payment_method&.fetch("id", nil),
          "payment_method" => compact_payment_method(payment_method),
          "product_id" => product&.fetch("id", nil),
          "product" => compact_product(product),
          "plan_id" => plan&.fetch("id", nil),
          "plan" => compact_plan(plan),
          "total" => total,
          "subtotal" => record["subtotal"] || total,
          "amount_after_fees" => record["amount_after_fees"] || total,
          "payment_method_type" => record["payment_method_type"] || payment_method&.fetch("payment_method_type",
                                                                                          nil) || "card",
          "refundable" => record.key?("refundable") ? record["refundable"] : true,
          "voidable" => record.key?("voidable") ? record["voidable"] : false,
          "status" => billing_default_status?(record["status"]) ? "paid" : record["status"],
          "substatus" => billing_default_status?(record["substatus"]) ? "succeeded" : record["substatus"]
        )
      end

      def payment_plan_updates(plan:, product:)
        compact_hash(
          "product_id" => product&.fetch("id", nil),
          "product" => compact_product(product),
          "plan_id" => plan&.fetch("id", nil),
          "plan" => compact_plan(plan)
        )
      end

      def membership_graph_attributes(payment:, membership_id:)
        @example_generator.generate("membership", compact_hash(
                                                    "id" => membership_id,
                                                    "status" => "active",
                                                    "company_id" => company_id_for(payment),
                                                    "company" => compact_company(payment["company"]),
                                                    "created_at" => payment["created_at"],
                                                    "updated_at" => payment["updated_at"] || payment["created_at"],
                                                    "payment_id" => payment["id"],
                                                    "plan_id" => payment["plan_id"] || payment.dig("plan", "id"),
                                                    "product_id" => payment["product_id"] || payment.dig("product",
                                                                                                         "id"),
                                                    "plan" => compact_plan(payment["plan"]),
                                                    "product" => compact_product(payment["product"]),
                                                    "member" => payment["member"] || compact_hash("id" => payment["member_id"]),
                                                    "user" => payment["user"]
                                                  ))
      end

      def invoice_graph_updates(record:, payload:, company:, product:, plan:, user:, timestamps:)
        updates = compact_hash(
          "company_id" => company_id_for(record) || payload["company_id"],
          "company" => compact_company(company),
          "collection_method" => payload["collection_method"],
          "payment_token_id" => payload["payment_token_id"],
          "member_id" => payload["member_id"] || record["member_id"] || user&.fetch("id", nil),
          "product_id" => product&.fetch("id", nil),
          "product" => compact_product(product),
          "status" => invoice_create_status(record, payload),
          "created_at" => record["created_at"] || timestamps["created_at"],
          "updated_at" => timestamps["updated_at"],
          "due_date" => payload["due_date"] || record["due_date"],
          "email_address" => payload["email_address"] || user&.fetch("email", nil),
          "customer_name" => payload["customer_name"] || user&.fetch("name", nil),
          "user" => user
        )

        return updates unless plan

        updates.merge(
          "current_plan" => plan_summary(plan),
          "plan_id" => plan["id"],
          "plan" => compact_plan(plan)
        )
      end

      def invoice_attributes_for_payment(payment:, invoice_id:)
        @example_generator.generate("invoice", compact_hash(
                                                 "id" => invoice_id,
                                                 "company_id" => company_id_for(payment),
                                                 "company" => compact_company(payment["company"]),
                                                 "created_at" => payment["created_at"],
                                                 "updated_at" => payment["updated_at"] || payment["created_at"],
                                                 "current_plan" => payment_plan_summary(payment),
                                                 "email_address" => payment.dig("user", "email"),
                                                 "status" => invoice_status_for_payment(payment),
                                                 "user" => payment["user"],
                                                 "payment_id" => payment["id"],
                                                 "plan_id" => payment["plan_id"] || payment.dig("plan", "id"),
                                                 "plan" => compact_plan(payment["plan"]),
                                                 "product_id" => payment["product_id"] || payment.dig("product", "id"),
                                                 "product" => compact_product(payment["product"])
                                               ))
      end

      def payment_plan_summary(payment)
        compact_hash(
          "id" => payment.dig("plan", "id") || payment["plan_id"],
          "currency" => payment["currency"] || payment.dig("plan", "currency"),
          "formatted_price" => format_price(payment["total"] || payment["subtotal"] || 10.0)
        )
      end

      def plan_summary(plan)
        compact_hash(
          "id" => plan["id"],
          "currency" => plan["currency"],
          "formatted_price" => format_price(plan["renewal_price"] || plan["initial_price"])
        )
      end

      def format_price(value)
        "$#{format("%.2f", (value || 10.0).to_f)}"
      end
    end
  end
end
