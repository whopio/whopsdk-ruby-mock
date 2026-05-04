# frozen_string_literal: true

require "json"
require "time"
require "whop_sdk"

module StressSuiteHelper
  module_function

  def reset_mock_configuration!
    original_configuration = WhopMock.configuration
    WhopMock.reset_configuration!
    WhopMock.configure do |config|
      config.spec_path = File.expand_path("../fixtures/openapi.yml", __dir__)
    end
    original_configuration
  end

  def restore_mock_configuration!(original_configuration)
    WhopMock.stop
    WhopMock.instance_variable_set(:@configuration, original_configuration)
  end

  def build_client(**overrides)
    defaults = { api_key: "Bearer test_key", max_retries: 0, base_url: "https://api.whop.com/api/v1" }
    WhopSDK::Client.new(**defaults, **overrides)
  end

  def create_payment_method!(last4: "4242", brand: "visa")
    token = WhopMock.generate_payment_token(last4: last4, exp_month: 12, exp_year: 2035, brand: brand, country: "US")
    status, _, body = WhopMock.requester.execute(
      method: :post,
      url: "https://api.whop.com/api/v1/payment_methods",
      body: { payment_token: token.fetch("id") }
    )
    raise "Unexpected payment method create status #{status}" unless status == 201

    JSON.parse(body.join)
  end

  def bootstrap_stack!(client:, company_title: "Stress Co", product_title: "Stress Product", plan_title: "Stress Plan",
                       member_id: "mb_stress")
    company = client.companies.create(title: company_title, description: "Stress suite company")
    product = client.products.create(company_id: company.id, title: product_title, visibility: :visible)
    plan = client.plans.create(
      company_id: company.id,
      product_id: product.id,
      title: plan_title,
      renewal_price: 20.0,
      currency: :usd,
      plan_type: :renewal,
      release_method: :buy_now
    )
    payment_method = create_payment_method!
    payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: member_id,
        payment_method_id: payment_method.fetch("id"),
        plan_id: plan.id
      }
    )
    invoice = client.invoices.retrieve(payment.to_h.fetch(:invoice_id))
    membership = client.memberships.retrieve(payment.to_h.fetch(:membership_id))

    {
      company: company,
      product: product,
      plan: plan,
      payment_method: payment_method,
      payment: payment,
      invoice: invoice,
      membership: membership
    }
  end

  def payment_ids_for(client:, company_id:, query: nil, statuses: nil)
    items = []
    params = { company_id: company_id, first: 50 }
    params[:query] = query if query
    params[:statuses] = statuses if statuses
    client.payments.list(**params).auto_paging_each { |item| items << item.to_h.fetch(:id) }
    items
  end

  def membership_ids_for(client:, company_id:, statuses: nil, plan_ids: nil)
    items = []
    params = { company_id: company_id, first: 50 }
    params[:statuses] = statuses if statuses
    params[:plan_ids] = plan_ids if plan_ids
    client.memberships.list(**params).auto_paging_each { |item| items << item.id }
    items
  end

  def invoice_ids_for(client:, company_id:, statuses: nil)
    items = []
    params = { company_id: company_id, first: 50 }
    params[:statuses] = statuses if statuses
    client.invoices.list(**params).auto_paging_each { |item| items << item.to_h.fetch(:id) }
    items
  end

  def refund_ids_for(client:, payment_id:)
    items = []
    client.refunds.list(payment_id: payment_id, first: 50).auto_paging_each { |item| items << item.to_h.fetch(:id) }
    items
  end
end
