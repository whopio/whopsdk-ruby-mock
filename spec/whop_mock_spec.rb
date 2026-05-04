# frozen_string_literal: true

require "stringio"
require "tmpdir"

RSpec.describe WhopMock do
  it "has a version number" do
    expect(WhopMock::VERSION).not_to be nil
  end

  it "prefers explicit spec_path, then auto-fetches from Stainless, then falls back to bundled" do
    configuration = WhopMock::Configuration.new
    configuration.auto_fetch_spec = false # Disable auto-fetch for this test

    # Falls back to bundled when auto-fetch disabled and no explicit path
    expect(configuration.resolved_spec_path).to eq(configuration.bundled_spec_path)

    # Explicit spec_path takes precedence
    Dir.mktmpdir do |dir|
      custom_path = File.join(dir, "custom-openapi.yml")
      File.write(custom_path, "openapi: 3.0.0\n")
      configuration.spec_path = custom_path

      expect(configuration.resolved_spec_path).to eq(custom_path)
    end
  end

  around do |example|
    original_configuration = WhopMock.configuration
    WhopMock.reset_configuration!
    WhopMock.configure do |config|
      config.spec_path = File.expand_path("fixtures/openapi.yml", __dir__)
    end
    example.run
    WhopMock.stop
    WhopMock.instance_variable_set(:@configuration, original_configuration)
  end

  it "boots a session with a parsed route registry" do
    session = WhopMock.start

    expect(session.route_registry.routes.map(&:operation_id)).to include("listMemberships", "createMembership")
    expect(session.schema_registry["Membership"]["x-resource-prefix"]).to eq("mem_")
  end

  it "supports create retrieve update delete and list through the mock requester" do
    requester = WhopMock.start.requester

    create_status, _, create_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/memberships",
      body: { name: "Starter", status: "active", company_id: "biz_123", created_at: "2026-04-29T10:00:00Z" }
    )
    created = JSON.parse(create_body.join)

    expect(create_status).to eq(201)
    expect(created.fetch("id")).to start_with("mem_")

    retrieve_status, _, retrieve_body = requester.execute(
      url: "https://api.whop.com/api/v1/memberships/#{created.fetch("id")}", method: :get
    )
    retrieved = JSON.parse(retrieve_body.join)

    expect(retrieve_status).to eq(200)
    expect(retrieved.fetch("name")).to eq("Starter")

    update_status, _, update_body = requester.execute(
      method: :patch,
      url: "https://api.whop.com/api/v1/memberships/#{created.fetch("id")}",
      body: { metadata: { "tier" => "premium" } }
    )
    updated = JSON.parse(update_body.join)

    expect(update_status).to eq(200)
    expect(updated.dig("metadata", "tier")).to eq("premium")

    list_status, response, list_body = requester.execute(method: :get, url: "https://api.whop.com/api/v1/memberships?limit=5")
    listed = JSON.parse(list_body.join)

    expect(list_status).to eq(200)
    expect(response).to be_a(Net::HTTPResponse)
    expect(response["content-type"]).to eq("application/json")
    expect(listed.dig("data", 0, "id")).to eq(created.fetch("id"))
    expect(listed.fetch("page_info")).to include("has_next_page", "has_previous_page")

    delete_status, _, delete_body = requester.execute(method: :delete, url: "https://api.whop.com/api/v1/memberships/#{created.fetch("id")}")
    deleted = JSON.parse(delete_body.join)

    expect(delete_status).to eq(200)
    expect(deleted.fetch("id")).to eq(created.fetch("id"))
    missing_status, _, missing_body = requester.execute(method: :get, url: "https://api.whop.com/api/v1/memberships/#{created.fetch("id")}")
    expect(missing_status).to eq(404)
    expect(JSON.parse(missing_body.join).fetch("error")).to include("membership not found")
  end

  it "hydrates nested relations from foreign keys in responses" do
    session = WhopMock.start
    session.store.insert("company", { "id" => "biz_123", "name" => "Acme" })

    status, _, body = session.requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/memberships",
      body: { name: "Pro", company_id: "biz_123", created_at: "2026-04-29T10:00:00Z" }
    )
    payload = JSON.parse(body.join)

    expect(status).to eq(201)
    expect(payload.dig("company", "name")).to eq("Acme")
  end

  it "raises one-shot prepared errors on the next matching action" do
    session = WhopMock.start
    WhopMock.prepare_error(StandardError, :create_membership, message: "declined", code: "card_declined")

    expect do
      session.requester.execute(method: :post, url: "https://api.whop.com/api/v1/memberships",
                                body: { name: "Starter" })
    end.to raise_error do |error|
      expect(error.message).to eq("declined")
      expect(error.code).to eq("card_declined")
    end

    status, _, body = session.requester.execute(method: :post, url: "https://api.whop.com/api/v1/memberships",
                                                body: { name: "Starter" })

    expect(status).to eq(201)
    expect(JSON.parse(body.join).fetch("name")).to eq("Starter")
  end

  it "rejects missing required payment create fields without persisting state" do
    session = WhopMock.start
    requester = session.requester

    expect do
      requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/payments",
        body: {
          body: {
            company_id: "biz_invalid"
          }
        }
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: member_id/)

    expect(session.store.list("payment")).to eq([])
    expect(session.store.list("invoice")).to eq([])
    expect(session.store.list("membership")).to eq([])
  end

  it "rejects invalid invoice create combinations without persisting state" do
    session = WhopMock.start
    requester = session.requester
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")

    expect do
      requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/invoices",
        body: {
          body: {
            collection_method: "charge_automatically",
            company_id: "biz_invalid_invoice",
            member_id: "mb_invalid_invoice",
            payment_token_id: token.fetch("id"),
            product_id: "prod_invalid_invoice",
            plan: {
              product_id: "prod_conflict"
            }
          }
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError, /conflicts/)

    expect(session.store.list("invoice")).to eq([])
    expect(session.store.list("plan")).to eq([])
  end

  it "rejects invalid action transitions and refund amounts" do
    requester = WhopMock.start.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_action_validation",
          member_id: "mb_action_validation",
          payment_method_id: "pmt_method_action_validation",
          plan: {
            currency: "usd",
            title: "Action Validation Plan",
            renewal_price: 10.0,
            product: {
              title: "Action Validation Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)

    expect do
      requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund",
        body: { partial_amount: 0 }
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /greater than 0/)

    expect do
      requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund",
        body: { partial_amount: 20.0 }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError, /exceeds remaining/)

    expect do
      requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/memberships/#{payment.fetch("membership_id")}/resume"
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError, /cannot resume/)
  end

  it "rejects invalid invoice and plan updates" do
    session = WhopMock.start
    requester = session.requester

    _, _, invoice_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/invoices",
      body: {
        body: {
          collection_method: "send_invoice",
          company_id: "biz_update_validation",
          member_id: "mb_update_validation",
          product_id: "prod_update_validation",
          plan: {}
        }
      }
    )
    invoice = JSON.parse(invoice_body.join)

    expect do
      requester.execute(
        method: :patch,
        url: "https://api.whop.com/api/v1/invoices/#{invoice.fetch("id")}",
        body: {
          product_id: "prod_a",
          plan: {
            product_id: "prod_b"
          }
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError, /conflicts/)

    session.store.insert("plan",
                         { "id" => "plan_update_validation", "company_id" => "biz_update_validation", "product_id" => "prod_update_validation",
                           "title" => "Starter", "renewal_price" => 10.0 })
    expect do
      requester.execute(
        method: :patch,
        url: "https://api.whop.com/api/v1/plans/plan_update_validation",
        body: {
          renewal_price: -5
        }
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /greater than or equal to 0/)
  end

  it "rejects invalid enum values through schema-backed validation" do
    requester = WhopMock.start.requester

    expect do
      requester.execute(
        method: :post,
        url: "https://api.whop.com/api/v1/products",
        body: {
          company_id: "biz_schema_enum",
          title: "Schema Product",
          visibility: "ghost"
        }
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /invalid product.visibility/)
  end

  it "rejects invalid list parameter combinations" do
    requester = WhopMock.start.requester

    expect do
      requester.execute(
        method: :get,
        url: "https://api.whop.com/api/v1/plans"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /company_id/)

    expect do
      requester.execute(
        method: :get,
        url: "https://api.whop.com/api/v1/payment_methods?company_id=biz_1&member_id=mb_1"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /exactly one of company_id or member_id/)

    expect do
      requester.execute(
        method: :get,
        url: "https://api.whop.com/api/v1/members?statuses[]=active"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /invalid statuses/)

    expect do
      requester.execute(
        method: :get,
        url: "https://api.whop.com/api/v1/transfers?order=status"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /invalid order/)
  end

  it "maps symbolic prepared errors to sdk error classes when available" do
    stub_const("WhopSDK", Module.new)
    stub_const("WhopSDK::Errors", Module.new)
    stub_const("WhopSDK::Errors::NotFoundError", Class.new(StandardError) do
      attr_reader :url, :status, :headers, :body

      def initialize(url:, status:, headers:, body:, request: nil, response: nil, message: nil, **_)
        @url = url
        @status = status
        @headers = headers
        @body = body
        @request = request
        @response = response
        super(message)
      end
    end)

    session = WhopMock.start
    WhopMock.prepare_error(:not_found, :create_membership, message: "missing", request_id: "req_123")

    expect do
      session.requester.execute(method: :post, url: "https://api.whop.com/api/v1/memberships",
                                body: { name: "Starter" })
    end.to raise_error(WhopSDK::Errors::NotFoundError) do |error|
      expect(error.message).to eq("missing")
      expect(error.request_id).to eq("req_123")
      expect(error.status).to eq(404)
    end
  end

  it "builds sdk-style timeout errors with transport metadata when available" do
    stub_const("WhopSDK", Module.new)
    stub_const("WhopSDK::Errors", Module.new)
    stub_const("WhopSDK::Errors::APITimeoutError", Class.new(StandardError) do
      attr_reader :url, :headers

      def initialize(url:, headers: nil, request: nil, response: nil, message: nil, **_)
        @url = url
        @headers = headers
        @request = request
        @response = response
        super(message)
      end
    end)

    session = WhopMock.start
    WhopMock.prepare_error(:timeout, :retrieve_membership, message: "Request timed out.")

    expect do
      session.requester.execute(method: :get, url: "https://api.whop.com/api/v1/memberships/mem_timeout")
    end.to raise_error(WhopSDK::Errors::APITimeoutError) do |error|
      expect(error.message).to eq("Request timed out.")
      expect(error.url.to_s).to include("/memberships/test")
      expect(error.headers).to include("content-type" => "application/json")
    end
  end

  it "logs request, response, and exception events when debug mode is enabled" do
    buffer = StringIO.new
    WhopMock.toggle_debug(true, io: buffer)
    session = WhopMock.start

    session.requester.execute(method: :post, url: "https://api.whop.com/api/v1/memberships",
                              body: { name: "Debug Starter" })
    WhopMock.prepare_error(StandardError, :retrieve_membership, message: "boom")

    expect do
      session.requester.execute(method: :get, url: "https://api.whop.com/api/v1/memberships/mem_debug")
    end.to raise_error(StandardError, "boom")

    output = buffer.string
    expect(output).to include('"event":"request"')
    expect(output).to include('"event":"response"')
    expect(output).to include('"event":"exception"')
    expect(output).to include('"/memberships"')
    expect(output).to include('"/memberships/mem_debug"')
  ensure
    WhopMock.toggle_debug(false)
  end

  it "applies lifecycle transitions for member action routes" do
    requester = WhopMock.start.requester
    _, _, create_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/memberships",
      body: { name: "Starter", status: "active" }
    )
    created = JSON.parse(create_body.join)

    status, _, cancel_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/memberships/#{created.fetch("id")}/cancel"
    )
    canceled = JSON.parse(cancel_body.join)

    expect(status).to eq(200)
    expect(canceled.fetch("status")).to eq("canceled")
    expect(canceled.fetch("canceled_at")).not_to be_nil
  end

  it "handles refund-style custom actions on payments" do
    requester = WhopMock.start.requester
    _, _, create_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_refund_action",
          member_id: "mb_refund_action",
          payment_method_id: "pmt_method_refund_action",
          plan: {
            currency: "usd",
            title: "Refund Action Plan",
            renewal_price: 10.0,
            product: {
              title: "Refund Action Product"
            }
          }
        }
      }
    )
    created = JSON.parse(create_body.join)

    status, _, refund_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments/#{created.fetch("id")}/refund",
      body: { reason: "requested_by_customer" }
    )
    refunded = JSON.parse(refund_body.join)

    expect(status).to eq(200)
    expect(refunded.fetch("status")).to eq("paid")
    expect(refunded.fetch("substatus")).to eq("refunded")
    expect(refunded.fetch("reason")).to eq("requested_by_customer")
    expect(refunded.fetch("refunded_at")).not_to be_nil
  end

  it "treats partial refunds differently from full refunds" do
    session = WhopMock.start
    requester = session.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_partial_refund",
          member_id: "mb_partial_refund",
          payment_method_id: "pmt_method_partial_refund",
          plan: {
            currency: "usd",
            title: "Partial Refund Plan",
            renewal_price: 10.0,
            product: {
              title: "Partial Refund Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)

    status, _, refund_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund",
      body: { partial_amount: 4.0 }
    )
    partially_refunded = JSON.parse(refund_body.join)

    expect(status).to eq(200)
    expect(partially_refunded.fetch("substatus")).to eq("partially_refunded")
    expect(partially_refunded.fetch("refunded_amount")).to eq(4.0)
    expect(partially_refunded.fetch("refundable")).to eq(true)
    expect(session.store.find("invoice", payment.fetch("invoice_id")).fetch("status")).to eq("paid")
    expect(session.store.find("membership", payment.fetch("membership_id")).fetch("status")).to eq("active")

    refund_event = WhopMock.mock_webhook_event("refund.updated",
                                               data: { id: session.store.list("refund").first.fetch("id") })
    expect(refund_event.dig("data", "amount")).to eq(4.0)
    expect(refund_event.dig("data", "payment", "id")).to eq(payment.fetch("id"))
  end

  it "accumulates repeated partial refunds and crosses into full-refund behavior on the last refund" do
    session = WhopMock.start
    requester = session.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_multi_partial",
          member_id: "mb_multi_partial",
          payment_method_id: "pmt_method_multi_partial",
          plan: {
            currency: "usd",
            title: "Multi Partial Plan",
            renewal_price: 10.0,
            product: {
              title: "Multi Partial Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)

    _, _, first_refund_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund",
      body: { partial_amount: 3.0 }
    )
    first_refund = JSON.parse(first_refund_body.join)
    expect(first_refund.fetch("substatus")).to eq("partially_refunded")
    expect(first_refund.fetch("refunded_amount")).to eq(3.0)
    expect(session.store.find("membership", payment.fetch("membership_id")).fetch("status")).to eq("active")
    expect(session.store.find("invoice", payment.fetch("invoice_id")).fetch("status")).to eq("paid")

    _, _, second_refund_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund",
      body: { partial_amount: 7.0 }
    )
    second_refund = JSON.parse(second_refund_body.join)
    expect(second_refund.fetch("substatus")).to eq("refunded")
    expect(second_refund.fetch("refunded_amount")).to eq(10.0)
    expect(second_refund.fetch("refundable")).to eq(false)
    expect(session.store.list("refund").length).to eq(2)
    expect(session.store.find("membership", payment.fetch("membership_id")).fetch("status")).to eq("canceled")
    expect(session.store.find("invoice", payment.fetch("invoice_id")).fetch("status")).to eq("refunded")

    refund_events = session.store.list("refund").sort_by { |record| record["created_at"].to_s }
    partial_event = WhopMock.mock_webhook_event("refund.updated", data: { id: refund_events.first.fetch("id") })
    final_payment_event = WhopMock.mock_webhook_event("payment.refunded", data: { id: payment.fetch("id") })
    expect(partial_event.dig("data", "amount")).to eq(3.0)
    expect(final_payment_event.dig("data", "substatus")).to eq("refunded")
  end

  it "creates related billing records during payment flows" do
    session = WhopMock.start
    requester = session.requester

    status, _, create_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_123",
          member_id: "mb_123",
          payment_method_id: "pmt_method_123",
          plan: {
            currency: "usd",
            title: "Monthly",
            renewal_price: 10.0,
            product: {
              title: "Starter"
            }
          }
        }
      }
    )
    created = JSON.parse(create_body.join)

    expect(status).to eq(201)
    expect(created.fetch("plan_id")).to start_with("plan_")
    expect(created.fetch("product_id")).to start_with("prod_")
    expect(created.fetch("membership_id")).to start_with("mem_")
    expect(created.fetch("invoice_id")).to start_with("inv_")
    expect(session.store.list("membership").length).to eq(1)
    expect(session.store.list("invoice").length).to eq(1)

    refund_status, _, refund_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments/#{created.fetch("id")}/refund"
    )
    refunded = JSON.parse(refund_body.join)

    expect(refund_status).to eq(200)
    expect(refunded.fetch("refunded_amount")).to eq(10.0)
    expect(session.store.list("refund").length).to eq(1)
    expect(session.store.list("invoice").first.fetch("status")).to eq("refunded")
  end

  it "reuses existing plan and product ids in create flows" do
    session = WhopMock.start
    session.store.insert("company", { "id" => "biz_existing", "title" => "Acme" })
    session.store.insert("product", { "id" => "prod_existing", "company_id" => "biz_existing", "title" => "Starter" })
    session.store.insert("plan",
                         { "id" => "plan_existing", "company_id" => "biz_existing", "product_id" => "prod_existing", "title" => "Monthly",
                           "currency" => "usd", "renewal_price" => 10.0 })

    requester = session.requester

    payment_status, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_existing",
          member_id: "mb_existing",
          payment_method_id: "pmt_method_existing",
          plan_id: "plan_existing"
        }
      }
    )
    payment = JSON.parse(payment_body.join)

    expect(payment_status).to eq(201)
    expect(payment.fetch("plan_id")).to eq("plan_existing")
    expect(payment.fetch("product_id")).to eq("prod_existing")

    invoice_status, _, invoice_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/invoices",
      body: {
        body: {
          collection_method: "send_invoice",
          company_id: "biz_existing",
          product_id: "prod_existing",
          plan: { title: "Invoice Plan", renewal_price: 15.0 },
          email_address: "user@example.com",
          customer_name: "Example User",
          save_as_draft: true
        }
      }
    )
    invoice = JSON.parse(invoice_body.join)

    expect(invoice_status).to eq(201)
    expect(invoice.dig("current_plan", "id")).to start_with("plan_")
    expect(invoice.fetch("product_id")).to eq("prod_existing")
    expect(invoice.fetch("status")).to eq("draft")
  end

  it "persists invoice member, token, due-date, and collection method fields on create" do
    session = WhopMock.start
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")
    session.store.insert("company", { "id" => "biz_invoice_variants", "title" => "Acme" })
    session.store.insert("product",
                         { "id" => "prod_invoice_variants", "company_id" => "biz_invoice_variants",
                           "title" => "Starter" })

    requester = session.requester

    invoice_status, _, invoice_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/invoices",
      body: {
        body: {
          collection_method: "charge_automatically",
          company_id: "biz_invoice_variants",
          member_id: "mb_invoice_variants",
          payment_token_id: token.fetch("id"),
          product_id: "prod_invoice_variants",
          plan: {},
          due_date: "2026-05-09T10:00:00Z",
          save_as_draft: true
        }
      }
    )
    invoice = JSON.parse(invoice_body.join)

    expect(invoice_status).to eq(201)
    expect(invoice.fetch("status")).to eq("draft")
    expect(invoice.fetch("due_date")).to eq("2026-05-09T10:00:00Z")
    expect(invoice.fetch("email_address")).to eq("mb_invoice_variants@example.com")
    expect(invoice.dig("user", "id")).to eq("mb_invoice_variants")

    stored = session.store.find("invoice", invoice.fetch("id"))
    expect(stored.fetch("collection_method")).to eq("charge_automatically")
    expect(stored.fetch("payment_token_id")).to eq(token.fetch("id"))
    expect(stored.fetch("member_id")).to eq("mb_invoice_variants")
    expect(session.store.find("plan",
                              invoice.dig("current_plan", "id")).fetch("product_id")).to eq("prod_invoice_variants")
  end

  it "couples invoice and membership state across linked billing actions" do
    session = WhopMock.start
    requester = session.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_linked",
          member_id: "mb_linked",
          payment_method_id: "pmt_method_linked",
          plan: {
            currency: "usd",
            title: "Linked Plan",
            renewal_price: 10.0,
            product: {
              title: "Linked Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)
    membership_id = payment.fetch("membership_id")
    invoice_id = payment.fetch("invoice_id")

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund")

    refunded_membership = session.store.find("membership", membership_id)
    refunded_invoice = session.store.find("invoice", invoice_id)
    expect(refunded_membership.fetch("status")).to eq("canceled")
    expect(refunded_membership.fetch("canceled_at")).not_to be_nil
    expect(refunded_invoice.fetch("status")).to eq("refunded")

    session.store.update("payment", payment.fetch("id"), "status" => "open", "substatus" => "pending")
    session.store.update("invoice", invoice_id, "status" => "open")
    session.store.update("membership", membership_id, "status" => "active", "payment_collection_paused" => true)

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/invoices/#{invoice_id}/mark_paid")

    paid_payment = session.store.find("payment", payment.fetch("id"))
    paid_membership = session.store.find("membership", membership_id)
    expect(paid_payment.fetch("status")).to eq("paid")
    expect(paid_payment.fetch("substatus")).to eq("succeeded")
    expect(paid_membership.fetch("status")).to eq("active")
    expect(paid_membership.fetch("payment_collection_paused")).to eq(false)

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/invoices/#{invoice_id}/void")

    voided_payment = session.store.find("payment", payment.fetch("id"))
    voided_membership = session.store.find("membership", membership_id)
    expect(voided_payment.fetch("status")).to eq("void")
    expect(voided_payment.fetch("substatus")).to eq("canceled")
    expect(voided_membership.fetch("status")).to eq("canceled")
    expect(voided_membership.fetch("canceled_at")).not_to be_nil
  end

  it "updates draft invoice plan summaries and failed billing state through linked actions" do
    session = WhopMock.start
    requester = session.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_failed",
          member_id: "mb_failed",
          payment_method_id: "pmt_method_failed",
          plan: {
            currency: "usd",
            title: "Draft Plan",
            renewal_price: 10.0,
            product: {
              title: "Draft Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)
    invoice_id = payment.fetch("invoice_id")
    membership_id = payment.fetch("membership_id")

    session.store.update("invoice", invoice_id, "status" => "draft")

    requester.execute(
      method: :patch,
      url: "https://api.whop.com/api/v1/invoices/#{invoice_id}",
      body: {
        email_address: "updated@example.com",
        plan: {
          title: "Updated Draft Plan",
          renewal_price: 25.0,
          currency: "usd"
        }
      }
    )

    updated_invoice = session.store.find("invoice", invoice_id)
    expect(updated_invoice.fetch("email_address")).to eq("updated@example.com")
    expect(updated_invoice.dig("current_plan", "formatted_price")).to eq("$25.00")

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/invoices/#{invoice_id}/mark_uncollectible")
    failed_payment = session.store.find("payment", payment.fetch("id"))
    paused_membership = session.store.find("membership", membership_id)
    expect(failed_payment.fetch("substatus")).to eq("failed")
    expect(paused_membership.fetch("status")).to eq("active")
    expect(paused_membership.fetch("payment_collection_paused")).to eq(true)

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/retry")
    retried_invoice = session.store.find("invoice", invoice_id)
    retried_membership = session.store.find("membership", membership_id)
    expect(retried_invoice.fetch("status")).to eq("open")
    expect(retried_membership.fetch("status")).to eq("active")
    expect(retried_membership.fetch("payment_collection_paused")).to eq(false)
  end

  it "fabricates webhook events and registers them in the event store" do
    session = WhopMock.start
    session.store.insert("membership", { "id" => "mem_existing", "status" => "active", "name" => "Starter" })

    event = WhopMock.mock_webhook_event("membership.activated", data: { id: "mem_existing" })

    expect(event.fetch("id")).to start_with("evt_")
    expect(event.fetch("type")).to eq("membership.activated")
    expect(event.dig("data", "id")).to eq("mem_existing")
    expect(event.dig("data", "name")).to eq("Starter")
    expect(session.store.find("event", event.fetch("id")).fetch("type")).to eq("membership.activated")
  end

  it "retrieves fabricated webhook events through the mock requester" do
    requester = WhopMock.start.requester
    event = WhopMock.mock_webhook_event("payment.succeeded")

    status, _, body = requester.execute(method: :get, url: "https://api.whop.com/api/v1/events/#{event.fetch("id")}")
    payload = JSON.parse(body.join)

    expect(status).to eq(200)
    expect(payload.fetch("id")).to eq(event.fetch("id"))
    expect(payload.fetch("type")).to eq("payment.succeeded")
  end

  it "signs webhook payloads with deterministic headers" do
    payload = { "id" => "evt_test", "type" => "membership.activated" }
    signed = WhopMock.sign_webhook(payload, secret: "topsecret", webhook_id: "msg_fixed123",
                                            timestamp: 1_700_000_000)

    expect(signed.fetch("webhook-id")).to eq("msg_fixed123")
    expect(signed.fetch("webhook-timestamp")).to eq("1700000000")
    expect(signed.fetch("webhook-signature")).to start_with("v1,")
    expect(signed.dig("headers", "webhook-id")).to eq("msg_fixed123")
    # Secret returned in whsec_ format for SDK compatibility
    expect(signed.fetch("secret")).to start_with("whsec_")
    expect(signed.fetch("payload")).to eq(JSON.generate(payload))
  end

  it "generates schema-driven examples with sensible defaults and overrides" do
    session = WhopMock.start

    membership = WhopMock.generate_example("membership", "status" => "past_due", "company" => { "title" => "Acme" })

    expect(membership.fetch("id")).to start_with("mem_")
    expect(membership.fetch("status")).to eq("past_due")
    expect(membership.dig("company", "id")).to start_with("biz_")
    expect(membership.dig("company", "title")).to eq("Acme")
    expect(membership.fetch("created_at")).not_to be_nil
    expect(session.example_generator.generate("payment_token").fetch("id")).to start_with("tok_")
  end

  it "seeds records through the public helper api" do
    WhopMock.start

    company = WhopMock.seed("company", "id" => "biz_seed_api", "title" => "Seed API Co")
    memberships = WhopMock.seed_many("membership", [
                                       { "id" => "mem_seed_api_1", "company_id" => "biz_seed_api",
                                         "status" => "active" },
                                       { "company_id" => "biz_seed_api", "status" => "past_due" }
                                     ])

    expect(company.fetch("title")).to eq("Seed API Co")
    expect(memberships.length).to eq(2)
    expect(memberships.last.fetch("id")).to start_with("mem_")
    expect(WhopMock.session.store.find("company", "biz_seed_api").fetch("title")).to eq("Seed API Co")
  end

  it "loads fixture files through the public helper api" do
    WhopMock.start

    loaded = WhopMock.load_fixtures(File.expand_path("fixtures/seeds.yml", __dir__))

    expect(loaded.fetch("company").first.fetch("id")).to eq("biz_seeded")
    expect(loaded.fetch("membership").length).to eq(2)
    expect(loaded.fetch("membership").last.fetch("id")).to start_with("mem_")
    expect(WhopMock.session.store.find("payment", "pay_seeded").fetch("substatus")).to eq("succeeded")
  end

  it "creates a test helper for stripe-style setup flows" do
    WhopMock.start
    helper = WhopMock.create_test_helper

    company = helper.create_company("title" => "Helper Co")
    product = helper.create_product("company_id" => company["id"], "title" => "Helper Product")
    plan = helper.create_plan("company_id" => company["id"], "product_id" => product["id"], "title" => "Helper Plan")
    membership = helper.create_membership("company_id" => company["id"], "product_id" => product["id"],
                                          "plan_id" => plan["id"], "status" => "active")

    expect(company.fetch("id")).to start_with("biz_")
    expect(product.fetch("company_id")).to eq(company["id"])
    expect(plan.fetch("product_id")).to eq(product["id"])
    expect(membership.fetch("plan_id")).to eq(plan["id"])
  end

  it "builds coherent billing stack helper scenarios" do
    WhopMock.start
    helper = WhopMock.create_test_helper

    stack = helper.create_billing_stack(
      "company" => { "title" => "Stack Co" },
      "product" => { "title" => "Stack Product" },
      "plan" => { "title" => "Stack Plan", "renewal_price" => 20.0 }
    )

    expect(stack.fetch("company").fetch("title")).to eq("Stack Co")
    expect(stack.fetch("product").fetch("company_id")).to eq(stack.fetch("company").fetch("id"))
    expect(stack.fetch("plan").fetch("product_id")).to eq(stack.fetch("product").fetch("id"))
    expect(stack.fetch("payment").fetch("plan_id")).to eq(stack.fetch("plan").fetch("id"))
    expect(stack.fetch("membership").fetch("id")).to eq(stack.fetch("payment").fetch("membership_id"))
    expect(stack.fetch("invoice").fetch("id")).to eq(stack.fetch("payment").fetch("invoice_id"))
  end

  it "builds failed renewal and refunded payment canned scenarios" do
    WhopMock.start
    helper = WhopMock.create_test_helper

    failed = helper.create_failed_renewal
    expect(failed.fetch("payment").fetch("substatus")).to eq("failed")
    expect(failed.fetch("invoice").fetch("status")).to eq("uncollectible")
    expect(failed.fetch("membership").fetch("status")).to eq("past_due")

    refunded = helper.create_refunded_payment
    expect(refunded.fetch("payment").fetch("substatus")).to eq("refunded")
    expect(refunded.fetch("invoice").fetch("status")).to eq("refunded")
    expect(refunded.fetch("membership").fetch("status")).to eq("canceled")
    expect(refunded.fetch("refund").fetch("id")).to start_with("ref_")
  end

  it "uses schema-driven defaults when fabricating webhook objects without store records" do
    WhopMock.start

    event = WhopMock.mock_webhook_event("company.updated")

    expect(event.dig("data", "id")).to start_with("biz_")
    expect(event.dig("data", "title")).not_to be_nil
  end

  it "fabricates payment and invoice webhook families with linked billing context" do
    session = WhopMock.start
    requester = session.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_webhook",
          member_id: "mb_webhook",
          payment_method_id: "pmt_method_webhook",
          plan: {
            currency: "usd",
            title: "Webhook Plan",
            renewal_price: 10.0,
            product: {
              title: "Webhook Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund")
    requester.execute(method: :post, url: "https://api.whop.com/api/v1/invoices/#{payment.fetch("invoice_id")}/mark_uncollectible")

    payment_event = WhopMock.mock_webhook_event("payment.refunded", data: { id: payment.fetch("id") })
    expect(payment_event.dig("data", "status")).to eq("paid")
    expect(payment_event.dig("data", "substatus")).to eq("refunded")
    expect(payment_event.dig("data", "membership", "id")).to eq(payment.fetch("membership_id"))
    expect(payment_event.dig("data", "invoice", "id")).to eq(payment.fetch("invoice_id"))

    invoice_event = WhopMock.mock_webhook_event("invoice.marked_uncollectible",
                                                data: { id: payment.fetch("invoice_id") })
    expect(invoice_event.dig("data", "status")).to eq("uncollectible")
    expect(invoice_event.dig("data", "payment", "id")).to eq(payment.fetch("id"))
    expect(invoice_event.dig("data", "payment", "substatus")).to eq("failed")
  end

  it "fabricates membership and refund webhook families from linked store state" do
    session = WhopMock.start
    requester = session.requester

    _, _, payment_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payments",
      body: {
        body: {
          company_id: "biz_member_webhook",
          member_id: "mb_member_webhook",
          payment_method_id: "pmt_method_member_webhook",
          plan: {
            currency: "usd",
            title: "Member Webhook Plan",
            renewal_price: 10.0,
            product: {
              title: "Member Webhook Product"
            }
          }
        }
      }
    )
    payment = JSON.parse(payment_body.join)
    membership_id = payment.fetch("membership_id")

    requester.execute(method: :post, url: "https://api.whop.com/api/v1/payments/#{payment.fetch("id")}/refund")
    refund = session.store.list("refund").first

    membership_event = WhopMock.mock_webhook_event("membership.canceled", data: { id: membership_id })
    expect(membership_event.dig("data", "status")).to eq("canceled")
    expect(membership_event.dig("data", "payment", "id")).to eq(payment.fetch("id"))
    expect(membership_event.dig("data", "invoice", "id")).to eq(payment.fetch("invoice_id"))

    refund_event = WhopMock.mock_webhook_event("refund.succeeded", data: { id: refund.fetch("id") })
    expect(refund_event.dig("data", "status")).to eq("succeeded")
    expect(refund_event.dig("data", "payment", "id")).to eq(payment.fetch("id"))
    expect(refund_event.fetch("livemode")).to eq(false)
    expect(refund_event.fetch("pending_webhooks")).to eq(0)
  end

  it "generates payment tokens and expands them into payment methods" do
    requester = WhopMock.start.requester
    token = WhopMock.generate_payment_token(last4: "1111", exp_month: 12, exp_year: 2035, brand: "mastercard")

    expect(token.fetch("id")).to start_with("tok_")

    status, _, body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payment_methods",
      body: { payment_token: token.fetch("id") }
    )
    payment_method = JSON.parse(body.join)

    expect(status).to eq(201)
    expect(payment_method.fetch("brand")).to eq("mastercard")
    expect(payment_method.fetch("last4")).to eq("1111")
    expect(payment_method.fetch("payment_token_id")).to eq(token.fetch("id"))
  end

  it "supports mock-native search helpers and routed search endpoints" do
    session = WhopMock.start
    session.store.insert("invoice", {
                           "id" => "inv_search_1",
                           "company_id" => "biz_search_mock",
                           "email_address" => "alpha@example.com",
                           "customer_name" => "Alpha Customer",
                           "status" => "paid"
                         })
    session.store.insert("invoice", {
                           "id" => "inv_search_2",
                           "company_id" => "biz_search_mock",
                           "email_address" => "beta@example.com",
                           "customer_name" => "Beta Customer",
                           "status" => "open"
                         })

    direct = WhopMock.search("invoice", query: "alpha", filters: { "company_id" => "biz_search_mock" })
    expect(direct.map { |record| record.fetch("id") }).to eq(["inv_search_1"])

    status, _, body = session.requester.execute(
      method: :get,
      url: "https://api.whop.com/api/v1/invoices/search?company_id=biz_search_mock&query=beta"
    )
    payload = JSON.parse(body.join)

    expect(status).to eq(200)
    expect(payload.fetch("data").map { |record| record.fetch("id") }).to eq(["inv_search_2"])
  end

  it "supports fallback handlers for unsupported routes" do
    requester = WhopMock.start.requester
    WhopMock.register_fallback do |method:, path:, query:, body:|
      next unless method.to_s == "get" && path == "/unsupported/path"

      [200, { "ok" => true, "query" => query, "body" => body }]
    end

    status, _, body = requester.execute(
      method: :get,
      url: "https://api.whop.com/api/v1/unsupported/path?foo=bar"
    )
    payload = JSON.parse(body.join)

    expect(status).to eq(200)
    expect(payload.fetch("ok")).to eq(true)
    expect(payload.fetch("query")).to eq("foo" => "bar")
  end

  it "accepts unknown fields on create and update payloads without raising errors" do
    # The mock is permissive about unknown fields since the real API is the gatekeeper.
    # This handles spec/SDK mismatches and allows SDK versions with newer fields.
    requester = WhopMock.start.requester

    # Create with unknown fields - should not raise
    _, _, created_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/companies",
      body: {
        title: "Unknown Field Co",
        bogus_flag: true
      }
    )
    company = JSON.parse(created_body.join)
    expect(company).to include("title" => "Unknown Field Co")

    _, _, created_body = requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/memberships",
      body: {
        name: "Known Membership",
        status: "active"
      }
    )
    membership = JSON.parse(created_body.join)

    # Update with unknown fields - should not raise
    _, _, updated_body = requester.execute(
      method: :patch,
      url: "https://api.whop.com/api/v1/memberships/#{membership.fetch("id")}",
      body: {
        metadata: { "tier" => "pro" },
        unsupported_change: "nope"
      }
    )
    updated = JSON.parse(updated_body.join)
    expect(updated).to include("metadata" => { "tier" => "pro" })
  end

  it "installs and restores the requester on an SDK-like client" do
    client = Class.new do
      def initialize
        @requester = Object.new
      end
    end.new

    session = WhopMock.start
    original = client.instance_variable_get(:@requester)

    WhopMock.install!(client)
    expect(client.instance_variable_get(:@requester)).to eq(session.requester)

    WhopMock.uninstall!(client)
    expect(client.instance_variable_get(:@requester)).to eq(original)
  end
end
