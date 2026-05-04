# frozen_string_literal: true

require "json"

module WhopMock
  class TestHelper
    def initialize(session)
      @session = session
    end

    def create_company(attributes = {})
      WhopMock.seed("company", attributes)
    end

    def create_product(attributes = {})
      attrs = stringify_keys(attributes)
      company = ensure_company(attrs.delete("company"), company_id: attrs["company_id"])
      attrs["company_id"] ||= company["id"] if company
      attrs["company"] ||= compact_company(company) if company
      WhopMock.seed("product", attrs)
    end

    def create_plan(attributes = {})
      attrs = stringify_keys(attributes)
      company = ensure_company(attrs.delete("company"), company_id: attrs["company_id"])
      product = ensure_product(attrs.delete("product"), company_id: company&.fetch("id", nil),
                                                        product_id: attrs["product_id"])
      attrs["company_id"] ||= company["id"] if company
      attrs["product_id"] ||= product["id"] if product
      attrs["company"] ||= compact_company(company) if company
      attrs["product"] ||= compact_product(product) if product
      WhopMock.seed("plan", attrs)
    end

    def create_membership(attributes = {})
      attrs = stringify_keys(attributes)
      company = ensure_company(attrs.delete("company"), company_id: attrs["company_id"])
      product = ensure_product(attrs.delete("product"), company_id: company&.fetch("id", nil),
                                                        product_id: attrs["product_id"])
      plan = ensure_plan(attrs.delete("plan"), company_id: company&.fetch("id", nil),
                                               product_id: product&.fetch("id", nil), plan_id: attrs["plan_id"])

      attrs["company_id"] ||= company["id"] if company
      attrs["product_id"] ||= product["id"] if product
      attrs["plan_id"] ||= plan["id"] if plan
      attrs["company"] ||= compact_company(company) if company
      attrs["product"] ||= compact_product(product) if product
      attrs["plan"] ||= compact_plan(plan) if plan

      WhopMock.seed("membership", attrs)
    end

    def create_payment(attributes = {})
      attrs = stringify_keys(attributes)
      company = ensure_company(attrs.delete("company"), company_id: attrs["company_id"])
      product = ensure_product(attrs.delete("product"), company_id: company&.fetch("id", nil),
                                                        product_id: attrs["product_id"])
      plan = ensure_plan(attrs.delete("plan"), company_id: company&.fetch("id", nil),
                                               product_id: product&.fetch("id", nil), plan_id: attrs["plan_id"])

      body = {
        "company_id" => company&.fetch("id", nil) || attrs["company_id"],
        "member_id" => attrs["member_id"] || @session.id_generator.generate("member"),
        "payment_method_id" => attrs["payment_method_id"] || @session.id_generator.generate("payment_method")
      }

      if plan
        body["plan_id"] = plan["id"]
      else
        plan_body = attrs["plan"] || {}
        plan_body["product_id"] ||= product["id"] if product
        plan_body["product"] ||= { "title" => "Example Product" } unless plan_body["product_id"]
        plan_body["currency"] ||= attrs["currency"] || "usd"
        body["plan"] = plan_body
      end

      body["metadata"] = attrs["metadata"] if attrs["metadata"]
      request = attrs["body"].is_a?(Hash) ? attrs["body"] : body

      create_via_request("/payments", request)
    end

    def create_invoice(attributes = {})
      attrs = stringify_keys(attributes)
      company = ensure_company(attrs.delete("company"), company_id: attrs["company_id"])
      product = ensure_product(attrs.delete("product"), company_id: company&.fetch("id", nil),
                                                        product_id: attrs["product_id"])

      body = {
        "collection_method" => attrs["collection_method"] || "send_invoice",
        "company_id" => company&.fetch("id", nil) || attrs["company_id"],
        "email_address" => attrs["email_address"] || "user@example.com",
        "customer_name" => attrs["customer_name"] || "Example User",
        "save_as_draft" => attrs.key?("save_as_draft") ? attrs["save_as_draft"] : true
      }

      if product
        body["product_id"] = product["id"]
      else
        body["product"] = attrs["product"] || { "title" => "Example Product" }
      end

      body["plan"] = attrs["plan"] || {
        "title" => "Example Invoice Plan",
        "renewal_price" => attrs["renewal_price"] || 10.0,
        "currency" => attrs["currency"] || "usd"
      }

      create_via_request("/invoices", attrs["body"].is_a?(Hash) ? attrs["body"] : body)
    end

    def create_refund(payment_or_id, attributes = {})
      payment_id = payment_or_id.is_a?(Hash) ? payment_or_id.fetch("id") : payment_or_id
      refund_via_request(payment_id, attributes)
      @session.store.list("refund").max_by { |record| record["created_at"].to_s }
    end

    def create_billing_stack(attributes = {})
      attrs = stringify_keys(attributes)
      company = create_company(attrs.fetch("company", {}))
      product = create_product(attrs.fetch("product", {}).merge("company_id" => company["id"]))
      plan = create_plan(attrs.fetch("plan", {}).merge("company_id" => company["id"], "product_id" => product["id"]))
      payment = create_payment(attrs.fetch("payment", {}).merge(
                                 "company_id" => company["id"],
                                 "plan_id" => plan["id"],
                                 "member_id" => attrs["member_id"] || @session.id_generator.generate("member")
                               ))
      invoice = @session.store.find("invoice", payment["invoice_id"])
      membership = @session.store.find("membership", payment["membership_id"])

      {
        "company" => company,
        "product" => product,
        "plan" => plan,
        "membership" => membership,
        "payment" => payment,
        "invoice" => invoice
      }
    end

    def create_failed_renewal(attributes = {})
      stack = create_billing_stack(attributes)
      payment = stack.fetch("payment")
      invoice = stack.fetch("invoice")
      membership = @session.store.find("membership", payment["membership_id"])

      @session.store.update("payment", payment["id"], {
                              "status" => "open",
                              "substatus" => "failed",
                              "failure_message" => "card declined"
                            })
      @session.store.update("invoice", invoice["id"], { "status" => "uncollectible" })
      @session.store.update("membership", membership["id"],
                            { "status" => "past_due", "payment_collection_paused" => true })

      {
        "company" => stack["company"],
        "product" => stack["product"],
        "plan" => stack["plan"],
        "payment" => @session.store.find("payment", payment["id"]),
        "invoice" => @session.store.find("invoice", invoice["id"]),
        "membership" => @session.store.find("membership", membership["id"])
      }
    end

    def create_refunded_payment(attributes = {})
      stack = create_billing_stack(attributes)
      refund = create_refund(stack.fetch("payment").fetch("id"))

      stack.merge(
        "payment" => @session.store.find("payment", stack.fetch("payment").fetch("id")),
        "invoice" => @session.store.find("invoice", stack.fetch("invoice").fetch("id")),
        "membership" => @session.store.find("membership", stack.fetch("payment").fetch("membership_id")),
        "refund" => refund
      )
    end

    private

    def ensure_company(company_attributes, company_id:)
      return company_attributes if company_attributes.is_a?(Hash) && company_attributes["id"]

      return @session.store.find("company", company_id) if company_id && @session.store.find("company", company_id)

      create_company((company_attributes || {}).merge("id" => company_id).compact)
    end

    def ensure_product(product_attributes, company_id:, product_id:)
      return product_attributes if product_attributes.is_a?(Hash) && product_attributes["id"]

      return @session.store.find("product", product_id) if product_id && @session.store.find("product", product_id)
      return nil if product_attributes.nil? && product_id.nil?

      create_product((product_attributes || {}).merge("id" => product_id, "company_id" => company_id).compact)
    end

    def ensure_plan(plan_attributes, company_id:, product_id:, plan_id:)
      return plan_attributes if plan_attributes.is_a?(Hash) && plan_attributes["id"]

      return @session.store.find("plan", plan_id) if plan_id && @session.store.find("plan", plan_id)
      return nil if plan_attributes.nil? && plan_id.nil?

      create_plan((plan_attributes || {}).merge("id" => plan_id, "company_id" => company_id,
                                                "product_id" => product_id).compact)
    end

    def create_via_request(path, body)
      status, _, response_body = @session.requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1#{path}",
        body: { body: body }
      )
      raise Error, "Unexpected status #{status} for #{path}" unless status == 201

      JSON.parse(response_body.join)
    end

    def refund_via_request(payment_id, attributes)
      @session.requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/payments/#{payment_id}/refund",
        body: stringify_keys(attributes)
      )
    end

    def compact_company(company)
      return nil unless company

      { "id" => company["id"], "title" => company["title"], "route" => company["route"] }.compact
    end

    def compact_product(product)
      return nil unless product

      { "id" => product["id"], "title" => product["title"], "company_id" => product["company_id"] }.compact
    end

    def compact_plan(plan)
      return nil unless plan

      { "id" => plan["id"], "title" => plan["title"], "product_id" => plan["product_id"],
        "currency" => plan["currency"] }.compact
    end

    def stringify_keys(hash)
      hash.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] =
          case value
          when Hash then stringify_keys(value)
          when Array then value.map { |item| item.is_a?(Hash) ? stringify_keys(item) : item }
          else value
          end
      end
    end
  end
end
