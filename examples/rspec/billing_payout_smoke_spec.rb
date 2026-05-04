# frozen_string_literal: true

require "json"
require_relative "support/whop_mock"

RSpec.describe "WhopMock billing/payout smoke flow" do
  it "drives billing and payout state through a real WhopSDK::Client" do
    client = build_whop_client

    company = client.companies.create(title: "Acme", description: "Billing smoke test")
    product = client.products.create(company_id: company.id, title: "Starter", visibility: :visible)
    plan = client.plans.create(
      company_id: company.id,
      product_id: product.id,
      title: "Monthly",
      renewal_price: 20.0,
      currency: :usd,
      plan_type: :renewal,
      release_method: :buy_now
    )

    token = WhopMock.generate_payment_token(
      last4: "4242",
      exp_month: 12,
      exp_year: 2035,
      brand: "visa",
      country: "US"
    )

    payment_method = WhopMock.requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payment_methods",
      body: { payment_token: token.fetch("id") }
    ).then do |status, _, body|
      raise "unexpected payment_method create status #{status}" unless status == 201

      JSON.parse(body.join)
    end

    payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: "mb_smoke_1",
        payment_method_id: payment_method.fetch("id"),
        plan_id: plan.id,
        metadata: { order_id: "order_smoke_1" }
      }
    )

    invoice = client.invoices.retrieve(payment.to_h.fetch(:invoice_id))
    membership = client.memberships.retrieve(payment.to_h.fetch(:membership_id))

    expect(invoice.to_h.fetch(:status)).to eq(:paid)
    expect(membership.to_h.fetch(:status)).to eq(:active)

    transfer = client.transfers.create(
      amount: 15.0,
      currency: :usd,
      origin_id: company.id,
      destination_id: "user_smoke_destination",
      metadata: { batch: "smoke" }
    )

    withdrawal = client.withdrawals.create(
      amount: 10.0,
      company_id: company.id,
      currency: :usd,
      payout_method_id: "pomethod_smoke_1",
      statement_descriptor: "PAYOUT"
    )

    expect(transfer.to_h.fetch(:origin_id)).to eq(company.id)
    expect(withdrawal.to_h.fetch(:company_id)).to eq(company.id)
  end
end
