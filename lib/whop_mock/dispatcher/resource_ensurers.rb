# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module ResourceEnsurers
      private

      def ensure_company_exists(company_id, company_payload = nil)
        return nil if company_id.nil?

        company = @store.find("company", company_id)
        return company if company

        @store.insert("company",
                      @example_generator.generate("company", { "id" => company_id }.merge(company_payload || {})))
      end

      def ensure_product_exists(product_id, company_id, product_payload = nil)
        product_id ||= @id_generator.generate("product") if product_payload&.any?
        return nil if product_id.nil?

        product = @store.find("product", product_id)
        return product if product

        company = ensure_company_exists(company_id)
        @store.insert("product", @example_generator.generate("product", {
          "id" => product_id,
          "company_id" => company_id,
          "company" => compact_company(company)
        }.merge(product_payload || {})))
      end

      def ensure_plan_exists(plan_id, company_id:, product_id:, source: {})
        plan_id ||= @id_generator.generate("plan") if source&.any?
        return nil if plan_id.nil?

        plan = @store.find("plan", plan_id)
        if plan
          return @store.update("plan", plan_id, compact_hash(source)) || plan if source&.any?

          return plan
        end

        company = ensure_company_exists(company_id)
        product = ensure_product_exists(product_id, company_id)

        overrides = {
          "id" => plan_id,
          "company_id" => company_id,
          "product_id" => product_id,
          "company" => compact_company(company),
          "product" => compact_product(product)
        }.merge(source || {})

        @store.insert("plan", @example_generator.generate("plan", overrides))
      end

      def company_id_for(record)
        record["company_id"] || record.dig("company", "id")
      end

      def product_id_for(record)
        record["product_id"] || record.dig("product", "id")
      end

      def ensure_payment_method_exists(payment_method_id, payment_method_payload = nil)
        return nil if payment_method_id.nil?

        payment_method = @store.find("payment_method", payment_method_id)
        return payment_method if payment_method

        @store.insert("payment_method", @example_generator.generate("payment_method", (payment_method_payload || {}).merge(
                                                                                        "id" => payment_method_id
                                                                                      )))
      end

      def default_timestamps(created_at = nil)
        timestamp = created_at || Time.now.utc.iso8601
        { "created_at" => timestamp, "updated_at" => timestamp }
      end

      def plan_price(plan)
        return nil unless plan.is_a?(Hash)

        plan["renewal_price"] || plan["initial_price"]
      end
    end
  end
end
