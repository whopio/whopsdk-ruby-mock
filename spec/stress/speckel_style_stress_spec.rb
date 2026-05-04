# frozen_string_literal: true

require "spec_helper"
require_relative "../support/stress_suite_helper"

RSpec.describe "Speckel-style stress suite" do
  around do |example|
    original_configuration = StressSuiteHelper.reset_mock_configuration!
    example.run
    StressSuiteHelper.restore_mock_configuration!(original_configuration)
  end

  it "drives a bootstrap graph through repeated reads and billing lifecycle mutations" do
    WhopMock.start
    client = StressSuiteHelper.build_client
    WhopMock.install!(client)

    stack = StressSuiteHelper.bootstrap_stack!(client: client, member_id: "mb_stress_bootstrap")
    company_id = stack.fetch(:company).id
    payment_id = stack.fetch(:payment).id
    invoice_id = stack.fetch(:invoice).id
    membership_id = stack.fetch(:membership).id
    plan_id = stack.fetch(:plan).id

    expect(StressSuiteHelper.membership_ids_for(client: client, company_id: company_id, statuses: [:active],
                                                plan_ids: [plan_id]))
      .to include(membership_id)
    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company_id, statuses: [:paid],
                                             query: membership_id))
      .to include(payment_id)
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company_id)).to include(invoice_id)

    refunded = client.payments.refund(payment_id)
    expect(refunded.to_h.fetch(:substatus).to_s).to eq("refunded")
    expect(StressSuiteHelper.refund_ids_for(client: client, payment_id: payment_id).length).to eq(1)
    expect(client.invoices.retrieve(invoice_id).to_h.fetch(:status).to_s).to eq("refunded")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("canceled")

    WhopMock.session.store.update("payment", payment_id, "status" => "open", "substatus" => "pending")
    WhopMock.session.store.update("invoice", invoice_id, "status" => "open")
    WhopMock.session.store.update("membership", membership_id, "status" => "active",
                                                               "payment_collection_paused" => false)

    expect(client.invoices.mark_uncollectible(invoice_id)).to eq(true)
    expect(client.payments.retrieve(payment_id).to_h.fetch(:substatus).to_s).to eq("failed")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:payment_collection_paused)).to eq(true)
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company_id, statuses: [:uncollectible]))
      .to include(invoice_id)

    retried = client.payments.retry_(payment_id)
    expect(retried.to_h.fetch(:status).to_s).to eq("pending")
    expect(client.invoices.retrieve(invoice_id).to_h.fetch(:status).to_s).to eq("open")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("active")

    expect(client.invoices.mark_paid(invoice_id)).to eq(true)
    expect(client.payments.retrieve(payment_id).to_h.fetch(:status).to_s).to eq("paid")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("active")

    payment_event = WhopMock.mock_webhook_event("payment.refunded", data: { id: payment_id })
    invoice_event = WhopMock.mock_webhook_event("invoice.marked_paid", data: { id: invoice_id })
    membership_event = WhopMock.mock_webhook_event("membership.activated", data: { id: membership_id })

    expect(payment_event.dig("data", "invoice", "id")).to eq(invoice_id)
    expect(invoice_event.dig("data", "payment", "id")).to eq(payment_id)
    expect(membership_event.dig("data", "payment", "id")).to eq(payment_id)
  end

  it "handles repeated list/filter/search reads after each mutation across overlapping records" do
    WhopMock.start
    client = StressSuiteHelper.build_client
    WhopMock.install!(client)

    primary = StressSuiteHelper.bootstrap_stack!(client: client, company_title: "Primary Co",
                                                 product_title: "Primary Product", plan_title: "Primary Plan", member_id: "mb_primary")
    secondary = StressSuiteHelper.bootstrap_stack!(client: client, company_title: "Secondary Co",
                                                   product_title: "Secondary Product", plan_title: "Secondary Plan", member_id: "mb_secondary")

    primary_company_id = primary.fetch(:company).id
    secondary_company_id = secondary.fetch(:company).id

    expect(StressSuiteHelper.payment_ids_for(client: client,
                                             company_id: primary_company_id)).to eq([primary.fetch(:payment).id])
    expect(StressSuiteHelper.payment_ids_for(client: client,
                                             company_id: secondary_company_id)).to eq([secondary.fetch(:payment).id])

    WhopMock.session.store.update("payment", primary.fetch(:payment).id, "user" => {
                                    "id" => "usr_primary",
                                    "email" => "primary@example.com",
                                    "name" => "Primary User",
                                    "username" => "primary-user"
                                  })
    WhopMock.session.store.update("payment", secondary.fetch(:payment).id, "user" => {
                                    "id" => "usr_secondary",
                                    "email" => "secondary@example.com",
                                    "name" => "Secondary User",
                                    "username" => "secondary-user"
                                  })

    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: primary_company_id,
                                             query: "primary@example.com"))
      .to eq([primary.fetch(:payment).id])
    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: secondary_company_id, query: "secondary-user"))
      .to eq([secondary.fetch(:payment).id])

    expect(client.payments.void(primary.fetch(:payment).id).to_h.fetch(:status).to_s).to eq("void")
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: primary_company_id, statuses: [:void]))
      .to include(primary.fetch(:invoice).id)
    expect(StressSuiteHelper.membership_ids_for(client: client, company_id: primary_company_id, statuses: [:canceled]))
      .to include(primary.fetch(:membership).id)

    expect(StressSuiteHelper.membership_ids_for(client: client, company_id: secondary_company_id, statuses: [:active]))
      .to eq([secondary.fetch(:membership).id])
  end

  it "supports failure injection in the middle of a multi-step billing flow" do
    WhopMock.start
    client = StressSuiteHelper.build_client
    WhopMock.install!(client)

    stack = StressSuiteHelper.bootstrap_stack!(client: client, member_id: "mb_failure")
    payment_id = stack.fetch(:payment).id
    invoice_id = stack.fetch(:invoice).id
    membership_id = stack.fetch(:membership).id
    company_id = stack.fetch(:company).id

    WhopMock.prepare_error(:rate_limit, :refund_payment, message: "Too many refund attempts")
    expect do
      client.payments.refund(payment_id)
    end.to raise_error(WhopSDK::Errors::RateLimitError)

    expect(StressSuiteHelper.refund_ids_for(client: client, payment_id: payment_id)).to eq([])
    expect(client.invoices.retrieve(invoice_id).to_h.fetch(:status).to_s).not_to eq("refunded")

    refunded = client.payments.refund(payment_id)
    expect(refunded.to_h.fetch(:substatus).to_s).to eq("refunded")
    expect(StressSuiteHelper.refund_ids_for(client: client, payment_id: payment_id).length).to eq(1)

    WhopMock.session.store.update("payment", payment_id, "status" => "open", "substatus" => "pending")
    WhopMock.session.store.update("invoice", invoice_id, "status" => "open")
    WhopMock.session.store.update("membership", membership_id, "status" => "active",
                                                               "payment_collection_paused" => true)

    WhopMock.prepare_error(:timeout, :mark_paid_invoice, message: "Request timed out.")
    expect do
      client.invoices.mark_paid(invoice_id)
    end.to raise_error(WhopSDK::Errors::APITimeoutError)

    expect(client.payments.retrieve(payment_id).to_h.fetch(:status).to_s).to eq("open")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:payment_collection_paused)).to eq(true)

    expect(client.invoices.mark_paid(invoice_id)).to eq(true)
    expect(client.payments.retrieve(payment_id).to_h.fetch(:status).to_s).to eq("paid")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("active")
    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company_id, statuses: [:paid]))
      .to include(payment_id)
  end

  it "drives a failure, retry, paid, partial-refund, and full-refund loop for the same member" do
    WhopMock.start
    client = StressSuiteHelper.build_client
    WhopMock.install!(client)

    company = client.companies.create(title: "Loop Co", description: "Stress loop company")
    product = client.products.create(company_id: company.id, title: "Loop Product", visibility: :visible)
    plan = client.plans.create(
      company_id: company.id,
      product_id: product.id,
      title: "Loop Plan",
      renewal_price: 20.0,
      currency: :usd,
      plan_type: :renewal,
      release_method: :buy_now
    )
    payment_method = StressSuiteHelper.create_payment_method!

    WhopMock.prepare_error(:unprocessable_entity, :create_payment, message: "Create rejected")
    expect do
      client.payments.create(
        body: {
          company_id: company.id,
          member_id: "mb_adversarial_loop",
          payment_method_id: payment_method.fetch("id"),
          plan_id: plan.id,
          metadata: { order_id: "loop_fail_1" }
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError)

    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company.id)).to eq([])
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company.id)).to eq([])
    expect(StressSuiteHelper.membership_ids_for(client: client, company_id: company.id)).to eq([])

    payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: "mb_adversarial_loop",
        payment_method_id: payment_method.fetch("id"),
        plan_id: plan.id,
        metadata: { order_id: "loop_success_1", cohort: "stress" }
      }
    )
    invoice_id = payment.to_h.fetch(:invoice_id)
    membership_id = payment.to_h.fetch(:membership_id)

    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company.id,
                                             query: "loop_success_1")).to eq([payment.id])
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company.id,
                                             statuses: [:paid])).to eq([invoice_id])
    expect(StressSuiteHelper.membership_ids_for(client: client, company_id: company.id, statuses: [:active],
                                                plan_ids: [plan.id])).to eq([membership_id])

    expect(client.invoices.mark_uncollectible(invoice_id)).to eq(true)
    expect(client.payments.retrieve(payment.id).to_h.fetch(:substatus).to_s).to eq("failed")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:payment_collection_paused)).to eq(true)
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company.id,
                                             statuses: [:uncollectible])).to eq([invoice_id])

    retried = client.payments.retry_(payment.id)
    expect(retried.to_h.fetch(:status).to_s).to eq("pending")
    expect(client.invoices.retrieve(invoice_id).to_h.fetch(:status).to_s).to eq("open")

    expect(client.invoices.mark_paid(invoice_id)).to eq(true)
    expect(client.payments.retrieve(payment.id).to_h.fetch(:status).to_s).to eq("paid")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("active")
    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company.id,
                                             statuses: [:paid])).to eq([payment.id])

    partial_refund = client.payments.refund(payment.id, partial_amount: 8.0)
    expect(partial_refund.to_h.fetch(:substatus).to_s).to eq("partially_refunded")
    expect(StressSuiteHelper.refund_ids_for(client: client, payment_id: payment.id).length).to eq(1)
    expect(client.invoices.retrieve(invoice_id).to_h.fetch(:status).to_s).to eq("paid")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("active")
    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company.id,
                                             query: "stress")).to eq([payment.id])

    final_refund = client.payments.refund(payment.id, partial_amount: 12.0)
    expect(final_refund.to_h.fetch(:substatus).to_s).to eq("refunded")
    expect(StressSuiteHelper.refund_ids_for(client: client, payment_id: payment.id).length).to eq(2)
    expect(client.invoices.retrieve(invoice_id).to_h.fetch(:status).to_s).to eq("refunded")
    expect(client.memberships.retrieve(membership_id).to_h.fetch(:status).to_s).to eq("canceled")

    webhook_client = StressSuiteHelper.build_client(webhook_key: WhopMock.sign_webhook({},
                                                                                       secret: "stress_loop_secret").fetch("secret"))
    failed_event = WhopMock.mock_webhook_event("payment.failed", data: { id: payment.id })
    pending_event = WhopMock.mock_webhook_event("payment.pending", data: { id: payment.id })
    partial_event = WhopMock.mock_webhook_event("refund.updated",
                                                data: { id: WhopMock.session.store.list("refund").first.fetch("id") })
    final_event = WhopMock.mock_webhook_event("payment.refunded", data: { id: payment.id })

    signed_failed = WhopMock.sign_webhook(failed_event, secret: webhook_client.webhook_key,
                                                        webhook_id: "msg_stress_failed", timestamp: Time.now.to_i)
    expect(webhook_client.webhooks.unwrap(signed_failed.fetch("payload"), headers: signed_failed.fetch("headers")))
      .to be_a(WhopSDK::Models::PaymentFailedWebhookEvent)

    signed_pending = WhopMock.sign_webhook(pending_event, secret: webhook_client.webhook_key,
                                                          webhook_id: "msg_stress_pending", timestamp: Time.now.to_i)
    expect(webhook_client.webhooks.unwrap(signed_pending.fetch("payload"), headers: signed_pending.fetch("headers")))
      .to be_a(WhopSDK::Models::PaymentPendingWebhookEvent)

    signed_partial = WhopMock.sign_webhook(partial_event, secret: webhook_client.webhook_key,
                                                          webhook_id: "msg_stress_partial", timestamp: Time.now.to_i)
    partial_unwrapped = webhook_client.webhooks.unwrap(signed_partial.fetch("payload"),
                                                       headers: signed_partial.fetch("headers"))
    expect(partial_unwrapped).to be_a(WhopSDK::Models::RefundUpdatedWebhookEvent)
    expect(partial_unwrapped.data.amount).to eq(8.0)

    signed_final = WhopMock.sign_webhook(final_event, secret: webhook_client.webhook_key,
                                                      webhook_id: "msg_stress_final", timestamp: Time.now.to_i)
    expect(JSON.parse(signed_final.fetch("payload")).fetch("type")).to eq("payment.refunded")
    expect(final_event.dig("data", "invoice", "id")).to eq(invoice_id)
    expect(final_event.dig("data", "membership", "id")).to eq(membership_id)
  end

  it "keeps repeated sdk-first payment cycles isolated for the same member across a shared plan and payment method" do
    WhopMock.start
    client = StressSuiteHelper.build_client
    WhopMock.install!(client)

    company = client.companies.create(title: "Shared Loop Co", description: "Shared plan loop company")
    product = client.products.create(company_id: company.id, title: "Shared Loop Product", visibility: :visible)
    plan = client.plans.create(
      company_id: company.id,
      product_id: product.id,
      title: "Shared Loop Plan",
      renewal_price: 25.0,
      currency: :usd,
      plan_type: :renewal,
      release_method: :buy_now
    )
    payment_method = StressSuiteHelper.create_payment_method!(last4: "1881")

    first_payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: "mb_shared_loop",
        payment_method_id: payment_method.fetch("id"),
        plan_id: plan.id,
        metadata: { order_id: "shared_1", stream: "first" }
      }
    )
    second_payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: "mb_shared_loop",
        payment_method_id: payment_method.fetch("id"),
        plan_id: plan.id,
        metadata: { order_id: "shared_2", stream: "second" }
      }
    )

    first_invoice_id = first_payment.to_h.fetch(:invoice_id)
    second_invoice_id = second_payment.to_h.fetch(:invoice_id)
    first_membership_id = first_payment.to_h.fetch(:membership_id)
    second_membership_id = second_payment.to_h.fetch(:membership_id)

    updated_first_invoice = client.invoices.update(
      first_invoice_id,
      email_address: "shared-loop-1@example.com",
      plan: {
        title: "Shared Loop Plan Updated",
        renewal_price: 31.0,
        currency: :usd
      }
    )
    expect(updated_first_invoice.current_plan.formatted_price).to eq("$31.00")

    expect(client.invoices.mark_uncollectible(first_invoice_id)).to eq(true)
    expect(client.payments.retry_(first_payment.id).to_h.fetch(:status).to_s).to eq("pending")
    expect(client.invoices.mark_paid(first_invoice_id)).to eq(true)
    expect(client.payments.void(second_payment.id).to_h.fetch(:status).to_s).to eq("void")

    first_payment_reloaded = client.payments.retrieve(first_payment.id)
    second_payment_reloaded = client.payments.retrieve(second_payment.id)
    first_invoice_reloaded = client.invoices.retrieve(first_invoice_id)
    second_invoice_reloaded = client.invoices.retrieve(second_invoice_id)
    first_membership_reloaded = client.memberships.retrieve(first_membership_id)
    second_membership_reloaded = client.memberships.retrieve(second_membership_id)

    expect(first_payment_reloaded.to_h.fetch(:status).to_s).to eq("paid")
    expect(first_invoice_reloaded.to_h.fetch(:status).to_s).to eq("paid")
    expect(first_invoice_reloaded.to_h.fetch(:email_address)).to eq("shared-loop-1@example.com")
    expect(first_membership_reloaded.to_h.fetch(:status).to_s).to eq("active")

    expect(second_payment_reloaded.to_h.fetch(:status).to_s).to eq("void")
    expect(second_invoice_reloaded.to_h.fetch(:status).to_s).to eq("void")
    expect(second_membership_reloaded.to_h.fetch(:status).to_s).to eq("canceled")

    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company.id,
                                             query: "shared_2")).to eq([second_payment.id])
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company.id,
                                             statuses: [:paid])).to include(first_invoice_id)
    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company.id,
                                             statuses: [:paid])).not_to include(second_invoice_id)
    expect(StressSuiteHelper.membership_ids_for(client: client, company_id: company.id,
                                                statuses: [:canceled])).to include(second_membership_id)

    webhook_client = StressSuiteHelper.build_client(webhook_key: WhopMock.sign_webhook({},
                                                                                       secret: "stress_shared_secret").fetch("secret"))
    paid_event = WhopMock.mock_webhook_event("invoice.paid", data: { id: first_invoice_id })
    voided_event = WhopMock.mock_webhook_event("invoice.voided", data: { id: second_invoice_id })

    signed_paid = WhopMock.sign_webhook(paid_event, secret: webhook_client.webhook_key, webhook_id: "msg_shared_paid",
                                                    timestamp: Time.now.to_i)
    signed_voided = WhopMock.sign_webhook(voided_event, secret: webhook_client.webhook_key,
                                                        webhook_id: "msg_shared_voided", timestamp: Time.now.to_i)

    expect(webhook_client.webhooks.unwrap(signed_paid.fetch("payload"), headers: signed_paid.fetch("headers")))
      .to be_a(WhopSDK::Models::InvoicePaidWebhookEvent)
    expect(webhook_client.webhooks.unwrap(signed_voided.fetch("payload"), headers: signed_voided.fetch("headers")))
      .to be_a(WhopSDK::Models::InvoiceVoidedWebhookEvent)
  end

  it "survives mixed create update and action failures in a shared invoice graph without dirtying other records" do
    WhopMock.start
    client = StressSuiteHelper.build_client
    WhopMock.install!(client)

    company = client.companies.create(title: "Failure Loop Co", description: "Failure loop company")
    product = client.products.create(company_id: company.id, title: "Failure Loop Product", visibility: :visible)
    token = WhopMock.generate_payment_token(last4: "1661", exp_month: 12, exp_year: 2035, brand: "visa", country: "US")
    payment_method = StressSuiteHelper.create_payment_method!(last4: "2662")

    WhopMock.prepare_error(:authentication, :create_invoice, message: "Missing auth")
    expect do
      client.invoices.create(
        body: {
          collection_method: :charge_automatically,
          company_id: company.id,
          member_id: "mb_failure_loop",
          payment_token_id: token.fetch("id"),
          product_id: product.id,
          plan: {},
          due_date: "2026-05-25T10:00:00Z",
          save_as_draft: true
        }
      )
    end.to raise_error(WhopSDK::Errors::AuthenticationError)

    expect(StressSuiteHelper.invoice_ids_for(client: client, company_id: company.id)).to eq([])

    first_invoice = client.invoices.create(
      body: {
        collection_method: :charge_automatically,
        company_id: company.id,
        member_id: "mb_failure_loop",
        payment_token_id: token.fetch("id"),
        product_id: product.id,
        plan: {},
        due_date: "2026-05-25T10:00:00Z",
        save_as_draft: true
      }
    )
    second_invoice = client.invoices.create(
      body: {
        collection_method: :send_invoice,
        company_id: company.id,
        member_id: "mb_failure_loop",
        product_id: product.id,
        plan: {},
        due_date: "2026-05-15T10:00:00Z",
        save_as_draft: true
      }
    )
    payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: "mb_failure_loop",
        payment_method_id: payment_method.fetch("id"),
        plan_id: first_invoice.current_plan.id,
        metadata: { order_id: "failure_loop_payment" }
      }
    )

    expect do
      client.invoices.update(
        first_invoice.id,
        product_id: "prod_conflict_failure_loop",
        plan: {
          product_id: product.id,
          title: "Conflicting Draft Plan",
          renewal_price: 40.0,
          currency: :usd
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError)

    expect do
      client.payments.refund(payment.id, partial_amount: 0)
    end.to raise_error(WhopSDK::Errors::BadRequestError)

    expect(StressSuiteHelper.refund_ids_for(client: client, payment_id: payment.id)).to eq([])

    updated_first_invoice = client.invoices.update(
      first_invoice.id,
      email_address: "stabilized@example.com",
      plan: {
        title: "Stabilized Draft Plan",
        renewal_price: 40.0,
        currency: :usd
      }
    )
    partial_refund = client.payments.refund(payment.id, partial_amount: 5.0)

    expect(updated_first_invoice.current_plan.formatted_price).to eq("$40.00")
    expect(partial_refund.to_h.fetch(:substatus).to_s).to eq("partially_refunded")
    expect(client.invoices.retrieve(second_invoice.id).to_h.fetch(:status).to_s).to eq("draft")
    expect(client.invoices.retrieve(second_invoice.id).current_plan.id).not_to eq(updated_first_invoice.current_plan.id)
    expect(StressSuiteHelper.payment_ids_for(client: client, company_id: company.id,
                                             query: "failure_loop_payment")).to eq([payment.id])

    webhook_client = StressSuiteHelper.build_client(webhook_key: WhopMock.sign_webhook({},
                                                                                       secret: "stress_failure_secret").fetch("secret"))
    refund_record = WhopMock.session.store.list("refund").first
    refund_event = WhopMock.mock_webhook_event("refund.updated", data: { id: refund_record.fetch("id") })
    created_event = WhopMock.mock_webhook_event("invoice.created", data: { id: second_invoice.id })

    signed_refund = WhopMock.sign_webhook(refund_event, secret: webhook_client.webhook_key,
                                                        webhook_id: "msg_failure_refund", timestamp: Time.now.to_i)
    signed_created = WhopMock.sign_webhook(created_event, secret: webhook_client.webhook_key,
                                                          webhook_id: "msg_failure_invoice", timestamp: Time.now.to_i)

    expect(webhook_client.webhooks.unwrap(signed_refund.fetch("payload"), headers: signed_refund.fetch("headers")))
      .to be_a(WhopSDK::Models::RefundUpdatedWebhookEvent)
    expect(webhook_client.webhooks.unwrap(signed_created.fetch("payload"), headers: signed_created.fetch("headers")))
      .to be_a(WhopSDK::Models::InvoiceCreatedWebhookEvent)
  end
end
