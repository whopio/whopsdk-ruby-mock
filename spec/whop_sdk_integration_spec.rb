# frozen_string_literal: true

require "whop_sdk"

RSpec.describe "WhopSDK integration" do
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

  def build_client(**overrides)
    defaults = { api_key: "Bearer test_key", max_retries: 0, base_url: "https://api.whop.com/api/v1" }
    WhopSDK::Client.new(**defaults, **overrides)
  end

  def membership_record(id:, status: "active", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "cancel_at_period_end" => false,
      "cancel_option" => nil,
      "canceled_at" => nil,
      "cancellation_reason" => nil,
      "company" => {
        "id" => "biz_test",
        "title" => "Acme Co"
      },
      "created_at" => created_at,
      "currency" => nil,
      "custom_field_responses" => [],
      "joined_at" => nil,
      "license_key" => nil,
      "manage_url" => nil,
      "member" => nil,
      "metadata" => {},
      "payment_collection_paused" => false,
      "plan" => {
        "id" => "plan_test"
      },
      "product" => {
        "id" => "prod_test",
        "title" => "Starter"
      },
      "promo_code" => nil,
      "renewal_period_end" => created_at,
      "renewal_period_start" => created_at,
      "status" => status,
      "updated_at" => created_at,
      "user" => {
        "id" => "usr_test",
        "email" => "user@example.com",
        "name" => "Test User",
        "username" => "testuser"
      }
    }
  end

  def payment_method_record(id:, created_at: "2026-04-29T10:00:00Z", last4: "1111")
    {
      "id" => id,
      "typename" => "CardPaymentMethod",
      "created_at" => created_at,
      "payment_method_type" => "card",
      "card" => {
        "brand" => "visa",
        "exp_month" => 12,
        "exp_year" => 35,
        "last4" => last4
      }
    }
  end

  def member_record(id:, company_id: "biz_member_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "access_level" => "customer",
      "company" => { "id" => company_id, "route" => "member-co", "title" => "Member Co" },
      "company_id" => company_id,
      "company_token_balance" => 0.0,
      "created_at" => created_at,
      "joined_at" => created_at,
      "most_recent_action" => "joined",
      "most_recent_action_at" => created_at,
      "phone" => nil,
      "status" => "joined",
      "updated_at" => created_at,
      "usd_total_spent" => 0.0,
      "user" => {
        "id" => "usr_#{id}",
        "email" => "#{id}@example.com",
        "name" => "Member #{id}",
        "username" => id.to_s
      }
    }
  end

  def payment_record(id:, status: "paid", substatus: "succeeded", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "amount_after_fees" => 10.0,
      "application_fee" => nil,
      "auto_refunded" => false,
      "billing_address" => nil,
      "billing_reason" => nil,
      "card_brand" => "visa",
      "card_last4" => "1111",
      "company" => { "id" => "biz_1", "route" => "acme", "title" => "Acme" },
      "created_at" => created_at,
      "currency" => nil,
      "dispute_alerted_at" => nil,
      "disputes" => nil,
      "failure_message" => nil,
      "financing_installments_count" => nil,
      "financing_transactions" => [],
      "last_payment_attempt" => nil,
      "member" => { "id" => "mb_1", "phone" => nil },
      "membership" => { "id" => "mem_1", "status" => "active" },
      "metadata" => {},
      "next_payment_attempt" => nil,
      "paid_at" => created_at,
      "payment_method" => {
        "id" => "pmt_method_1",
        "card" => { "brand" => "visa", "exp_month" => 12, "exp_year" => 35, "last4" => "1111" },
        "created_at" => created_at,
        "payment_method_type" => "card"
      },
      "payment_method_type" => "card",
      "payments_failed" => nil,
      "plan" => { "id" => "plan_1", "internal_notes" => nil },
      "product" => { "id" => "prod_1", "route" => "starter", "title" => "Starter" },
      "promo_code" => nil,
      "refundable" => true,
      "refunded_amount" => nil,
      "refunded_at" => nil,
      "resolutions" => nil,
      "retryable" => false,
      "status" => status,
      "substatus" => substatus,
      "subtotal" => 10.0,
      "tax_amount" => nil,
      "tax_behavior" => nil,
      "tax_refunded_amount" => nil,
      "total" => 10.0,
      "updated_at" => created_at,
      "usd_total" => 10.0,
      "user" => { "id" => "usr_1", "email" => "user@example.com", "name" => "Test User", "username" => "testuser" },
      "voidable" => false
    }
  end

  def company_record(id:, created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "affiliate_instructions" => nil,
      "created_at" => created_at,
      "description" => "Creator tools",
      "featured_affiliate_product" => nil,
      "logo" => { "url" => "https://example.com/logo.png" },
      "member_count" => 10,
      "metadata" => {},
      "owner_user" => { "id" => "usr_owner", "name" => "Owner", "username" => "owner" },
      "published_reviews_count" => 2,
      "route" => "acme",
      "send_customer_emails" => true,
      "social_links" => [],
      "target_audience" => nil,
      "title" => "Acme",
      "updated_at" => created_at,
      "verified" => true
    }
  end

  def product_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "company_id" => company_id,
      "company" => { "id" => company_id, "route" => "acme", "title" => "Acme" },
      "created_at" => created_at,
      "custom_cta" => "get_access",
      "custom_cta_url" => nil,
      "custom_statement_descriptor" => nil,
      "description" => "Product description",
      "external_identifier" => nil,
      "gallery_images" => [],
      "global_affiliate_percentage" => nil,
      "global_affiliate_status" => "disabled",
      "headline" => nil,
      "member_affiliate_percentage" => nil,
      "member_affiliate_status" => "disabled",
      "member_count" => 5,
      "owner_user" => { "id" => "usr_owner", "name" => "Owner", "username" => "owner" },
      "product_tax_code" => nil,
      "published_reviews_count" => 1,
      "route" => "starter",
      "title" => "Starter",
      "updated_at" => created_at,
      "verified" => true,
      "visibility" => "visible"
    }
  end

  def plan_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "company_id" => company_id,
      "billing_period" => 30,
      "collect_tax" => false,
      "company" => { "id" => company_id, "title" => "Acme" },
      "created_at" => created_at,
      "currency" => "usd",
      "custom_fields" => [],
      "description" => "Monthly plan",
      "expiration_days" => nil,
      "initial_price" => 10.0,
      "internal_notes" => nil,
      "invoice" => nil,
      "member_count" => 3,
      "payment_method_configuration" => { "disabled" => [], "enabled" => ["card"],
                                          "include_platform_defaults" => true },
      "plan_type" => "renewal",
      "product" => { "id" => "prod_1", "title" => "Starter" },
      "purchase_url" => "https://whop.com/acme/starter",
      "release_method" => "buy_now",
      "renewal_price" => 10.0,
      "split_pay_required_payments" => nil,
      "stock" => nil,
      "tax_type" => "exclusive",
      "title" => "Monthly",
      "trial_period_days" => nil,
      "unlimited_stock" => true,
      "updated_at" => created_at,
      "visibility" => "visible"
    }
  end

  def promo_code_record(id:, company_id: "biz_1", product_id: nil, created_at: "2026-04-29T10:00:00Z", status: "active")
    {
      "id" => id,
      "amount_off" => 20.0,
      "churned_users_only" => false,
      "code" => "SPRING20",
      "company_id" => company_id,
      "company" => { "id" => company_id, "title" => "Acme" },
      "created_at" => created_at,
      "currency" => "usd",
      "duration" => "repeating",
      "existing_memberships_only" => false,
      "expires_at" => nil,
      "new_users_only" => true,
      "one_per_customer" => true,
      "plan_ids" => [],
      "product_id" => product_id,
      "product" => product_id ? { "id" => product_id, "title" => "Starter" } : nil,
      "promo_duration_months" => 3,
      "promo_type" => "percentage",
      "status" => status,
      "stock" => 100,
      "unlimited_stock" => false,
      "uses" => 0
    }
  end

  def checkout_configuration_record(id:, company_id: "biz_1", plan_id: nil, created_at: "2026-04-29T10:00:00Z",
                                    mode: "payment")
    {
      "id" => id,
      "affiliate_code" => nil,
      "allow_promo_codes" => true,
      "company_id" => company_id,
      "created_at" => created_at,
      "currency" => "usd",
      "metadata" => { "source" => "seeded-checkout" },
      "mode" => mode,
      "payment_method_configuration" => if mode == "setup"
                                          {
                                            "disabled" => [],
                                            "enabled" => ["card"],
                                            "include_platform_defaults" => true
                                          }
                                        end,
      "plan_id" => plan_id,
      "plan" => plan_id ? plan_record(id: plan_id, company_id: company_id, created_at: created_at) : nil,
      "purchase_url" => mode == "setup" ? "https://whop.com/checkout/setup?session=#{id}" : "https://whop.com/checkout/#{plan_id}?session=#{id}",
      "redirect_url" => "https://example.test/checkout/complete"
    }
  end

  def invoice_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "company_id" => company_id,
      "created_at" => created_at,
      "current_plan" => { "id" => "plan_1", "currency" => "usd", "formatted_price" => "$10.00" },
      "due_date" => nil,
      "email_address" => "user@example.com",
      "fetch_invoice_token" => "inv_token_123",
      "number" => "INV-001",
      "status" => "open",
      "user" => { "id" => "usr_1", "name" => "Test User", "username" => "testuser" }
    }
  end

  def fee_markup_record(id:, company_id: "biz_1", fee_type: "crypto_withdrawal_markup",
                        created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "company_id" => company_id,
      "created_at" => created_at,
      "fee_type" => fee_type,
      "fixed_fee_usd" => 1.25,
      "metadata" => { "source" => "seeded" },
      "notes" => "Default markup",
      "percentage_fee" => 2.5,
      "updated_at" => created_at
    }
  end

  def topup_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "company_id" => company_id,
      "created_at" => created_at,
      "currency" => "usd",
      "failure_message" => nil,
      "paid_at" => created_at,
      "status" => "paid",
      "total" => 50.0
    }
  end

  def dispute_record(id:, company_id: "biz_1", payment_id: "pay_dispute_1", plan_id: "plan_1", product_id: "prod_1",
                     created_at: "2026-04-29T10:00:00Z", status: "needs_response", editable: true)
    {
      "id" => id,
      "access_activity_log" => nil,
      "amount" => 20.0,
      "billing_address" => nil,
      "cancellation_policy_attachment" => nil,
      "cancellation_policy_disclosure" => nil,
      "company" => { "id" => company_id, "title" => "Acme" },
      "company_id" => company_id,
      "created_at" => created_at,
      "currency" => "usd",
      "customer_communication_attachment" => nil,
      "customer_email_address" => "buyer@example.com",
      "customer_name" => "Buyer Example",
      "editable" => editable,
      "needs_response_by" => "2026-05-10T10:00:00Z",
      "notes" => nil,
      "payment" => { "id" => payment_id },
      "payment_id" => payment_id,
      "plan" => { "id" => plan_id },
      "plan_id" => plan_id,
      "product" => { "id" => product_id, "title" => "Disputed Product" },
      "product_id" => product_id,
      "product_description" => nil,
      "reason" => "fraudulent",
      "refund_policy_attachment" => nil,
      "refund_policy_disclosure" => nil,
      "refund_refusal_explanation" => nil,
      "service_date" => nil,
      "status" => status,
      "uncategorized_attachment" => nil,
      "visa_rdr" => false
    }
  end

  def dispute_alert_record(id:, dispute_id: "disp_1", payment_id: "pay_dispute_1", created_at: "2026-04-29T10:00:00Z",
                           alert_type: "dispute")
    {
      "id" => id,
      "alert_type" => alert_type,
      "amount" => 20.0,
      "charge_for_alert" => true,
      "created_at" => created_at,
      "currency" => "usd",
      "dispute" => {
        "id" => dispute_id,
        "amount" => 20.0,
        "created_at" => created_at,
        "currency" => "usd",
        "reason" => "fraudulent",
        "status" => "needs_response"
      },
      "dispute_id" => dispute_id,
      "payment" => {
        "id" => payment_id,
        "billing_reason" => "purchase",
        "card_brand" => "visa",
        "card_last4" => "4242",
        "created_at" => created_at,
        "currency" => "usd",
        "dispute_alerted_at" => created_at,
        "member" => { "id" => "mb_dispute_alert", "phone" => "+15555550111" },
        "membership" => { "id" => "mem_dispute_alert", "status" => "active" },
        "paid_at" => created_at,
        "payment_method_type" => "card",
        "subtotal" => 20.0,
        "total" => 20.0,
        "usd_total" => 20.0,
        "user" => {
          "id" => "usr_dispute_alert",
          "email" => "alert-user@example.com",
          "name" => "Alert User",
          "username" => "alert-user"
        }
      },
      "payment_id" => payment_id,
      "transaction_date" => created_at
    }
  end

  def ledger_account_record(id:, owner_type: "Company", owner_id: "biz_1")
    owner =
      if owner_type == "User"
        {
          "id" => owner_id,
          "name" => "Ledger User",
          "typename" => "User",
          "username" => "ledger-user"
        }
      else
        {
          "id" => owner_id,
          "route" => "acme",
          "title" => "Acme",
          "typename" => "Company"
        }
      end

    {
      "id" => id,
      "balances" => [
        {
          "balance" => 125.5,
          "currency" => "usd",
          "pending_balance" => 10.0,
          "reserve_balance" => 5.0
        }
      ],
      "ledger_type" => "primary",
      "owner" => owner,
      "payments_approval_status" => "approved",
      "payout_account_details" => {
        "id" => "poacct_ledger_1",
        "address" => {
          "city" => "New York",
          "country" => "US",
          "line1" => "123 Main",
          "line2" => nil,
          "postal_code" => "10001",
          "state" => "NY"
        },
        "business_name" => "Acme LLC",
        "business_representative" => {
          "date_of_birth" => "1990-01-01",
          "first_name" => "Avery",
          "last_name" => "Owner",
          "middle_name" => nil
        },
        "email" => "owner@acme.test",
        "latest_verification" => {
          "id" => "ver_ledger_1",
          "last_error_code" => nil,
          "last_error_reason" => nil,
          "status" => "verified"
        },
        "phone" => "+15555550123",
        "status" => "verified"
      },
      "transfer_fee" => 1.5
    }
  end

  def payout_account_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "address" => {
        "city" => "New York",
        "country" => "US",
        "line1" => "123 Main",
        "line2" => nil,
        "postal_code" => "10001",
        "state" => "NY"
      },
      "business_name" => "Acme LLC",
      "business_representative" => {
        "date_of_birth" => "1990-01-01",
        "first_name" => "Avery",
        "last_name" => "Owner",
        "middle_name" => nil
      },
      "email" => "owner@acme.test",
      "latest_verification" => {
        "id" => "ver_1",
        "last_error_code" => nil,
        "last_error_reason" => nil,
        "status" => "verified"
      },
      "phone" => "+15555550123",
      "status" => "verified"
    }
  end

  def payout_method_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "account_reference" => "••••6789",
      "company" => { "id" => company_id },
      "created_at" => created_at,
      "currency" => "usd",
      "destination" => {
        "category" => "bank_account",
        "country_code" => "US",
        "name" => "Avery Owner"
      },
      "institution_name" => "Example Bank",
      "is_default" => true,
      "nickname" => "Primary USD"
    }
  end

  def transfer_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "amount" => 25.0,
      "created_at" => created_at,
      "currency" => "usd",
      "destination" => {
        "id" => "user_transfer_1",
        "name" => "Transfer Recipient",
        "typename" => "User",
        "username" => "transfer-recipient"
      },
      "destination_id" => "user_transfer_1",
      "destination_ledger_account_id" => "ledger_dest_1",
      "fee_amount" => 0.0,
      "metadata" => {},
      "notes" => nil,
      "origin" => {
        "id" => company_id,
        "route" => "acme",
        "title" => "Acme",
        "typename" => "Company"
      },
      "origin_id" => company_id,
      "origin_ledger_account_id" => "ledger_origin_1",
      "status" => "paid",
      "updated_at" => created_at
    }
  end

  def withdrawal_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "amount" => 15.0,
      "company_id" => company_id,
      "created_at" => created_at,
      "currency" => "usd",
      "error_code" => nil,
      "error_message" => nil,
      "estimated_availability" => nil,
      "fee_amount" => 0.0,
      "fee_type" => nil,
      "ledger_account" => {
        "id" => "ledger_#{company_id}",
        "company_id" => company_id
      },
      "markup_fee" => 0.0,
      "payout_token" => {
        "id" => "pomethod_1",
        "created_at" => created_at,
        "destination_currency_code" => "usd",
        "nickname" => "Primary USD",
        "payer_name" => "Avery Owner"
      },
      "payout_method_id" => "pomethod_1",
      "speed" => "standard",
      "status" => "pending",
      "trace_code" => nil
    }
  end

  def entry_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z", status: "pending")
    {
      "id" => id,
      "company_id" => company_id,
      "created_at" => created_at,
      "custom_field_responses" => [
        {
          "id" => "cfr_#{id}",
          "answer" => "Weekly growth tactics",
          "question" => "What are you hoping to learn?"
        }
      ],
      "plan" => { "id" => "plan_entry_1" },
      "product" => { "id" => "prod_entry_1", "title" => "Waitlist Product" },
      "status" => status,
      "user" => {
        "id" => "usr_entry_1",
        "email" => "entry@example.com",
        "name" => "Entry User",
        "username" => "entry-user"
      }
    }
  end

  def course_lesson_interaction_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z", completed: true)
    {
      "id" => id,
      "company_id" => company_id,
      "completed" => completed,
      "course" => {
        "id" => "course_1",
        "experience" => { "id" => "exp_1" },
        "title" => "Creator Course"
      },
      "created_at" => created_at,
      "lesson" => {
        "id" => "lesson_1",
        "chapter" => { "id" => "chapter_1" },
        "title" => "Getting Started"
      },
      "user" => {
        "id" => "usr_course_1",
        "name" => "Course User",
        "username" => "course-user"
      }
    }
  end

  def verification_record(id:, company_id: "biz_1", status: "verified")
    {
      "id" => id,
      "company_id" => company_id,
      "last_error_code" => nil,
      "last_error_reason" => nil,
      "status" => status
    }
  end

  def resolution_center_case_record(id:, company_id: "biz_1", payment_id: "pay_resolution_1",
                                    member_id: "mem_resolution_1", created_at: "2026-04-29T10:00:00Z", status: "merchant_response_needed")
    {
      "id" => id,
      "company_id" => company_id,
      "company" => { "id" => company_id, "title" => "Acme" },
      "created_at" => created_at,
      "customer_appealed" => false,
      "customer_response_actions" => %w[respond appeal],
      "due_date" => "2026-05-06T10:00:00Z",
      "issue" => "unauthorized_transaction",
      "member" => { "id" => member_id },
      "merchant_appealed" => false,
      "merchant_response_actions" => %w[accept deny respond],
      "payment" => {
        "id" => payment_id,
        "created_at" => created_at,
        "currency" => "usd",
        "paid_at" => created_at,
        "subtotal" => 25.0,
        "total" => 25.0
      },
      "platform_response_actions" => %w[request_merchant_info platform_refund],
      "resolution_events" => [
        {
          "id" => "rcevt_#{id}",
          "action" => "created",
          "created_at" => created_at,
          "details" => "Resolution case opened.",
          "reporter_type" => "system"
        }
      ],
      "status" => status,
      "updated_at" => created_at,
      "user" => {
        "id" => "usr_resolution_1",
        "name" => "Resolution User",
        "username" => "resolution-user"
      }
    }
  end

  def webhook_record(id:, resource_id: "biz_1", created_at: "2026-04-29T10:00:00Z", enabled: true)
    {
      "id" => id,
      "api_version" => "v1",
      "child_resource_events" => false,
      "created_at" => created_at,
      "enabled" => enabled,
      "events" => ["payment.succeeded", "invoice.paid"],
      "resource_id" => resource_id,
      "testable_events" => ["payment.succeeded", "invoice.paid"],
      "url" => "https://example.com/hooks/#{id}",
      "webhook_secret" => "whsec_dGVzdF9zZWNyZXQ="
    }
  end

  def refund_record(id:, created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "amount" => 10.0,
      "created_at" => created_at,
      "currency" => "usd",
      "payment" => { "id" => "pay_1" },
      "provider" => "stripe",
      "provider_created_at" => nil,
      "reference_status" => nil,
      "reference_type" => nil,
      "reference_value" => nil,
      "status" => "succeeded"
    }
  end

  def setup_intent_record(id:, company_id: "biz_1", created_at: "2026-04-29T10:00:00Z")
    {
      "id" => id,
      "company_id" => company_id,
      "checkout_configuration" => { "id" => "chk_1" },
      "company" => { "id" => company_id },
      "created_at" => created_at,
      "error_message" => nil,
      "member" => {
        "id" => "mb_1",
        "user" => { "id" => "usr_1", "email" => "user@example.com", "name" => "Test User", "username" => "testuser" }
      },
      "metadata" => {},
      "payment_method" => {
        "id" => "pmt_method_1",
        "card" => { "brand" => "visa", "exp_month" => 12, "exp_year" => 35, "last4" => "1111" },
        "created_at" => created_at,
        "mailing_address" => nil,
        "payment_method_type" => "card"
      },
      "status" => "succeeded"
    }
  end

  it "retrieves and updates memberships through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("membership", membership_record(id: "mem_sdk_1"))

    client = build_client
    WhopMock.install!(client)

    membership = client.memberships.retrieve("mem_sdk_1")
    expect(membership).to be_a(WhopSDK::Membership)
    expect(membership.id).to eq("mem_sdk_1")
    expect(membership.product.title).to eq("Starter")

    updated = client.memberships.update("mem_sdk_1", metadata: { "tier" => "pro" })
    expect(updated.metadata[:tier]).to eq("pro")
  end

  it "maps missing resources to WhopSDK::Errors::NotFoundError" do
    client = build_client
    WhopMock.install!(client, spec_path: File.expand_path("fixtures/openapi.yml", __dir__))

    expect do
      client.memberships.retrieve("mem_missing")
    end.to raise_error(WhopSDK::Errors::NotFoundError)
  end

  it "raises real sdk transport-style injected errors" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    WhopMock.prepare_error(:rate_limit, :retrieve_membership, message: "Too many requests")
    expect do
      client.memberships.retrieve("mem_rate_limited")
    end.to raise_error(WhopSDK::Errors::RateLimitError) do |error|
      expect(error.status).to eq(429)
      expect(error.url.to_s).to include("/memberships/test")
      expect(error.body).to eq("error" => "Too many requests")
    end

    WhopMock.prepare_error(:timeout, :retrieve_membership, message: "Request timed out.")
    expect do
      client.memberships.retrieve("mem_timeout")
    end.to raise_error(WhopSDK::Errors::APITimeoutError) do |error|
      expect(error.status).to be_nil
      expect(error.url.to_s).to include("/memberships/test")
    end
  end

  it "injects payment create failures without leaving partial billing graph state behind" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_create_fail_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_create_fail_sdk", company_id: "biz_create_fail_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Create Fail Product"
                                    ))
    session.store.insert("plan", plan_record(id: "plan_create_fail_sdk", company_id: "biz_create_fail_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_create_fail_sdk",
                                   "product" => { "id" => "prod_create_fail_sdk", "title" => "Create Fail Product" },
                                   "currency" => "usd",
                                   "renewal_price" => 30.0
                                 ))
    session.store.insert("payment_method",
                         payment_method_record(id: "pmt_method_create_fail_sdk", created_at: "2026-04-29T10:00:00Z",
                                               last4: "4242"))

    client = build_client
    WhopMock.install!(client)

    WhopMock.prepare_error(:unprocessable_entity, :create_payment, message: "Payment create rejected")

    expect do
      client.payments.create(
        body: {
          company_id: "biz_create_fail_sdk",
          member_id: "mb_create_fail_sdk",
          payment_method_id: "pmt_method_create_fail_sdk",
          plan_id: "plan_create_fail_sdk",
          metadata: { order_id: "order_fail_create" }
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError) do |error|
      expect(error.status).to eq(422)
      expect(error.url.to_s).to include("/payments")
    end

    expect(session.store.list("payment")).to be_empty
    expect(session.store.list("invoice")).to be_empty
    expect(session.store.list("membership")).to be_empty
    expect(session.store.list("refund")).to be_empty
    expect(session.store.list("plan").count { |record| record["id"] == "plan_create_fail_sdk" }).to eq(1)
    expect(session.store.list("payment_method").count do |record|
      record["id"] == "pmt_method_create_fail_sdk"
    end).to eq(1)

    successful_payment = client.payments.create(
      body: {
        company_id: "biz_create_fail_sdk",
        member_id: "mb_create_fail_sdk_ok",
        payment_method_id: "pmt_method_create_fail_sdk",
        plan_id: "plan_create_fail_sdk"
      }
    )
    expect(successful_payment.id).to start_with("pay_")
    expect(session.store.list("payment").length).to eq(1)
  end

  it "injects invoice create failures without leaving partial invoice graph state behind" do
    session = WhopMock.start
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")
    session.store.insert("company", company_record(id: "biz_invoice_fail_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_invoice_fail_sdk", company_id: "biz_invoice_fail_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Invoice Fail Product"
                                    ))

    client = build_client
    WhopMock.install!(client)

    WhopMock.prepare_error(:authentication, :create_invoice, message: "Invoice create unauthorized")

    expect do
      client.invoices.create(
        body: {
          collection_method: :charge_automatically,
          company_id: "biz_invoice_fail_sdk",
          member_id: "mb_invoice_fail_sdk",
          payment_token_id: token.fetch("id"),
          product_id: "prod_invoice_fail_sdk",
          plan: {},
          due_date: "2026-05-14T10:00:00Z",
          save_as_draft: true
        }
      )
    end.to raise_error(WhopSDK::Errors::AuthenticationError) do |error|
      expect(error.status).to eq(401)
      expect(error.url.to_s).to include("/invoices")
    end

    expect(session.store.list("invoice")).to be_empty
    expect(session.store.list("membership")).to be_empty
    expect(session.store.list("refund")).to be_empty
    expect(session.store.list("product").count { |record| record["id"] == "prod_invoice_fail_sdk" }).to eq(1)
    expect(session.store.list("payment_token").count { |record| record["id"] == token.fetch("id") }).to eq(1)
    expect(session.store.list("plan")).to be_empty

    successful_invoice = client.invoices.create(
      body: {
        collection_method: :charge_automatically,
        company_id: "biz_invoice_fail_sdk",
        member_id: "mb_invoice_fail_sdk_ok",
        payment_token_id: token.fetch("id"),
        product_id: "prod_invoice_fail_sdk",
        plan: {},
        due_date: "2026-05-14T10:00:00Z",
        save_as_draft: true
      }
    )
    expect(successful_invoice.id).to start_with("inv_")
    expect(session.store.list("invoice").length).to eq(1)
  end

  it "rejects missing required create fields with real sdk bad-request errors" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    expect do
      client.payments.create(
        body: {
          company_id: "biz_missing_fields"
        }
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("missing required fields")
      expect(error.url.to_s).to include("/api/v1/")
    end

    expect do
      client.companies.create(description: "missing title")
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("missing required fields: title")
    end
  end

  it "rejects invalid create combinations with real sdk unprocessable-entity errors" do
    session = WhopMock.start
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")
    session.store.insert("company", company_record(id: "biz_invalid_combo_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product",
                         product_record(id: "prod_invalid_combo_sdk", company_id: "biz_invalid_combo_sdk",
                                        created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("plan", plan_record(id: "plan_invalid_combo_sdk", company_id: "biz_invalid_combo_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_invalid_combo_sdk",
                                   "product" => { "id" => "prod_invalid_combo_sdk", "title" => "Starter" }
                                 ))

    client = build_client
    WhopMock.install!(client)

    expect do
      client.payments.create(
        body: {
          company_id: "biz_invalid_combo_sdk",
          member_id: "mb_invalid_combo_sdk",
          payment_method_id: "pmt_method_invalid_combo_sdk",
          plan_id: "plan_invalid_combo_sdk",
          product_id: "prod_other_sdk"
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError) do |error|
      expect(error.status).to eq(422)
      expect(error.message).to include("conflicts")
    end

    expect do
      client.invoices.create(
        body: {
          collection_method: :charge_automatically,
          company_id: "biz_invalid_combo_sdk",
          member_id: "mb_invalid_combo_sdk",
          payment_token_id: token.fetch("id"),
          product_id: "prod_invalid_combo_sdk",
          plan: {
            product_id: "prod_conflict_sdk"
          }
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError) do |error|
      expect(error.status).to eq(422)
      expect(error.message).to include("conflicts")
    end

    expect(session.store.list("payment")).to eq([])
    expect(session.store.list("invoice")).to eq([])
    expect(session.store.list("membership")).to eq([])
  end

  it "rejects invalid update combinations with real sdk errors" do
    session = WhopMock.start
    client = build_client
    WhopMock.install!(client)

    invoice = client.invoices.create(
      body: {
        collection_method: :send_invoice,
        company_id: "biz_update_combo_sdk",
        member_id: "mb_update_combo_sdk",
        product_id: "prod_update_combo_sdk",
        plan: {},
        save_as_draft: true
      }
    )

    expect do
      client.invoices.update(
        invoice.id,
        product_id: "prod_a",
        plan: {
          product_id: "prod_b"
        }
      )
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError) do |error|
      expect(error.status).to eq(422)
      expect(error.message).to include("conflicts")
    end

    session.store.insert("plan", plan_record(id: "plan_update_combo_sdk", company_id: "biz_update_combo_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_update_combo_sdk",
                                   "product" => { "id" => "prod_update_combo_sdk", "title" => "Starter" }
                                 ))
    expect do
      client.plans.update("plan_update_combo_sdk", renewal_price: -1)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("greater than or equal to 0")
    end
  end

  it "rejects invalid enum values with schema-backed sdk errors" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    expect do
      client.products.create(company_id: "biz_schema_enum_sdk", title: "Schema Product", visibility: "ghost")
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid product.visibility")
    end

    expect do
      client.invoices.create(
        body: {
          collection_method: "wire",
          company_id: "biz_schema_enum_sdk",
          member_id: "mb_schema_enum_sdk",
          product_id: "prod_schema_enum_sdk",
          plan: {}
        }
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid invoice.collection_method")
    end
  end

  it "rejects invalid action transitions with real sdk errors" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_action_validation_sdk",
        member_id: "mb_action_validation_sdk",
        payment_method_id: "pmt_method_action_validation_sdk",
        plan: {
          currency: :usd,
          title: "Action Validation Plan",
          renewal_price: 10.0,
          product: {
            title: "Action Validation Product"
          }
        }
      }
    )

    expect do
      client.payments.refund(payment.id, partial_amount: 0)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("greater than 0")
    end

    expect do
      client.payments.refund(payment.id, partial_amount: 20.0)
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError) do |error|
      expect(error.status).to eq(422)
      expect(error.message).to include("exceeds remaining")
    end

    expect do
      client.memberships.resume(payment.to_h.fetch(:membership_id))
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError) do |error|
      expect(error.status).to eq(422)
      expect(error.message).to include("cannot resume")
    end
  end

  it "rejects invalid list parameter combinations with real sdk errors" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    expect do
      client.plans.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("company_id")
    end

    expect do
      client.products.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("company_id")
    end

    expect do
      client.setup_intents.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("company_id")
    end

    expect do
      client.webhooks.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("company_id")
    end

    expect do
      client.payment_methods.list(company_id: "biz_1", member_id: "mb_1", first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("exactly one of company_id or member_id")
    end

    expect do
      client.members.list(statuses: [:active], first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid statuses")
    end

    expect do
      client.members.list(order: :status, first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid order")
    end

    expect do
      client.members.list(direction: :sideways, first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid direction")
    end

    expect do
      client.members.list(access_level: :viewer, first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid access_level")
    end

    expect do
      client.transfers.list(order: :status, first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError) do |error|
      expect(error.status).to eq(400)
      expect(error.message).to include("invalid order")
    end
  end

  it "supports sdk cursor pagination and auto_paging_each" do
    session = WhopMock.start
    session.store.insert("membership", membership_record(id: "mem_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("membership", membership_record(id: "mem_sdk_2", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    page = client.memberships.list(first: 1)
    expect(page).to be_a(WhopSDK::Internal::CursorPage)
    expect(page.data.length).to eq(1)
    expect(page.next_page?).to eq(true)

    ids = []
    page.auto_paging_each { |membership| ids << membership.id }

    expect(ids).to eq(%w[mem_sdk_2 mem_sdk_1])
  end

  it "applies membership list filters and ordering through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("membership", membership_record(id: "mem_filter_1", status: "active", created_at: "2026-04-29T10:00:00Z").merge(
                                         "company_id" => "biz_filter",
                                         "plan" => { "id" => "plan_filter_a" },
                                         "product" => { "id" => "prod_filter" },
                                         "user" => { "id" => "usr_filter_1", "email" => "one@example.com",
                                                     "name" => "One", "username" => "one" }
                                       ))
    session.store.insert("membership", membership_record(id: "mem_filter_2", status: "paused", created_at: "2026-04-29T11:00:00Z").merge(
                                         "company_id" => "biz_filter",
                                         "plan" => { "id" => "plan_filter_b" },
                                         "product" => { "id" => "prod_filter" },
                                         "user" => { "id" => "usr_filter_2", "email" => "two@example.com",
                                                     "name" => "Two", "username" => "two" }
                                       ))
    session.store.insert("membership", membership_record(id: "mem_filter_3", status: "active", created_at: "2026-04-29T12:00:00Z").merge(
                                         "company_id" => "biz_other",
                                         "plan" => { "id" => "plan_other" },
                                         "product" => { "id" => "prod_other" },
                                         "user" => { "id" => "usr_other", "email" => "other@example.com",
                                                     "name" => "Other", "username" => "other" }
                                       ))

    client = build_client
    WhopMock.install!(client)

    ids = []
    client.memberships.list(
      company_id: "biz_filter",
      statuses: [:active],
      plan_ids: ["plan_filter_a"],
      direction: :asc,
      order: :created_at
    ).auto_paging_each { |item| ids << item.id }

    expect(ids).to eq(%w[mem_filter_1])
  end

  it "supports sdk custom action methods like cancel" do
    session = WhopMock.start
    session.store.insert("membership", membership_record(id: "mem_sdk_1", status: "active"))

    client = build_client
    WhopMock.install!(client)

    canceled = client.memberships.cancel("mem_sdk_1")

    expect(canceled).to be_a(WhopSDK::Membership)
    expect(canceled.status).to eq(:canceled)
    expect(canceled.canceled_at).not_to be_nil
  end

  it "supports membership pause, resume, add_free_days, and uncancel through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("membership",
                         membership_record(id: "mem_sdk_actions", status: "active", created_at: "2026-04-29T10:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    paused = client.memberships.pause("mem_sdk_actions")
    expect(paused.to_h.fetch(:status).to_s).to eq("active")
    expect(paused.to_h.fetch(:payment_collection_paused)).to eq(true)

    resumed = client.memberships.resume("mem_sdk_actions")
    expect(resumed.to_h.fetch(:status).to_s).to eq("active")
    expect(resumed.to_h.fetch(:payment_collection_paused)).to eq(false)

    extended = client.memberships.add_free_days("mem_sdk_actions", free_days: 5)
    expect(extended.renewal_period_end).to be > Time.parse("2026-04-29T10:00:00Z")

    client.memberships.cancel("mem_sdk_actions")
    uncanceled = client.memberships.uncancel("mem_sdk_actions")
    expect(uncanceled.to_h.fetch(:status).to_s).to eq("active")
    expect(uncanceled.canceled_at).to be_nil
    expect(uncanceled.cancel_at_period_end).to eq(false)
  end

  it "retrieves and lists payment methods through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payment_method",
                         payment_method_record(id: "pmt_method_sdk_1").merge("company_id" => "biz_payment_methods_sdk"))
    session.store.insert("payment_method",
                         payment_method_record(id: "pmt_method_sdk_2", created_at: "2026-04-29T11:00:00Z",
                                               last4: "2222").merge("company_id" => "biz_payment_methods_sdk"))

    client = build_client
    WhopMock.install!(client)

    payment_method = client.payment_methods.retrieve("pmt_method_sdk_1")
    expect(payment_method.class.name).to include("PaymentMethodRetrieveResponse::CardPaymentMethod")
    expect(payment_method.to_h.fetch(:card).last4).to eq("1111")

    page = client.payment_methods.list(company_id: "biz_payment_methods_sdk", first: 1)
    expect(page).to be_a(WhopSDK::Internal::CursorPage)
    ids = []
    page.auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[pmt_method_sdk_2 pmt_method_sdk_1])
  end

  it "retrieves, lists, and refunds payments through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payment", payment_record(id: "pay_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("payment", payment_record(id: "pay_sdk_2", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    payment = client.payments.retrieve("pay_sdk_1")
    expect(payment).to be_a(WhopSDK::Payment)
    expect(payment.to_h.fetch(:id)).to eq("pay_sdk_1")
    expect(payment.to_h.fetch(:status)).to eq(:paid)

    page = client.payments.list(first: 1)
    expect(page).to be_a(WhopSDK::Internal::CursorPage)
    ids = []
    page.auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[pay_sdk_2 pay_sdk_1])

    refunded = client.payments.refund("pay_sdk_1")
    expect(refunded).to be_a(WhopSDK::Payment)
    expect(refunded.to_h.fetch(:status)).to eq(:paid)
    expect(refunded.to_h.fetch(:substatus)).to eq(:refunded)
    expect(refunded.to_h.fetch(:refunded_at)).not_to be_nil
  end

  it "applies payment list filters and search through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payment", payment_record(id: "pay_search_1", status: "paid", substatus: "succeeded", created_at: "2026-04-29T10:00:00Z").merge(
                                      "company_id" => "biz_search",
                                      "plan_id" => "plan_search",
                                      "product_id" => "prod_search",
                                      "total" => 10.0,
                                      "user" => { "id" => "usr_search_1", "email" => "alpha@example.com", "name" => "Alpha User",
                                                  "username" => "alpha" }
                                    ))
    session.store.insert("payment", payment_record(id: "pay_search_2", status: "open", substatus: "failed", created_at: "2026-04-29T11:00:00Z").merge(
                                      "company_id" => "biz_search",
                                      "plan_id" => "plan_search",
                                      "product_id" => "prod_search",
                                      "total" => 0.0,
                                      "subtotal" => 0.0,
                                      "user" => { "id" => "usr_search_2", "email" => "beta@example.com",
                                                  "name" => "Beta User", "username" => "beta" }
                                    ))
    session.store.insert("payment", payment_record(id: "pay_search_3", status: "paid", substatus: "succeeded", created_at: "2026-04-29T12:00:00Z").merge(
                                      "company_id" => "biz_other",
                                      "plan_id" => "plan_other",
                                      "product_id" => "prod_other",
                                      "user" => { "id" => "usr_search_3", "email" => "gamma@example.com", "name" => "Gamma User",
                                                  "username" => "gamma" }
                                    ))

    client = build_client
    WhopMock.install!(client)

    ids = []
    client.payments.list(
      company_id: "biz_search",
      statuses: [:paid],
      product_ids: ["prod_search"],
      query: "alpha@example.com",
      include_free: false
    ).auto_paging_each { |item| ids << item.to_h.fetch(:id) }

    expect(ids).to eq(%w[pay_search_1])
  end

  it "lists payment fees through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payment", payment_record(id: "pay_fee_sdk_1", created_at: "2026-04-29T10:00:00Z").merge(
                                      "currency" => "usd",
                                      "total" => 20.0,
                                      "subtotal" => 20.0,
                                      "application_fee" => 1.5
                                    ))

    client = build_client
    WhopMock.install!(client)

    fees = []
    client.payments.list_fees("pay_fee_sdk_1", first: 10).auto_paging_each { |item| fees << item.to_h }

    expect(fees.length).to be >= 2
    expect(fees.first).to include(:amount, :currency, :name, :type)
    expect(fees.map { |fee| fee[:type].to_s }).to include("application_fee")
  end

  it "supports payment retry and void through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payment", payment_record(id: "pay_sdk_action", status: "open", substatus: "failed", created_at: "2026-04-29T10:00:00Z").merge(
                                      "failure_message" => "card declined",
                                      "last_payment_attempt" => nil,
                                      "voidable" => true
                                    ))

    client = build_client
    WhopMock.install!(client)

    retried = client.payments.retry_("pay_sdk_action")
    expect(retried.to_h.fetch(:status)).to eq(:pending)
    expect(retried.to_h.fetch(:substatus)).to eq(:pending)
    expect(retried.to_h.fetch(:failure_message)).to be_nil
    expect(retried.to_h.fetch(:last_payment_attempt)).not_to be_nil

    voided = client.payments.void("pay_sdk_action")
    expect(voided.to_h.fetch(:status)).to eq(:void)
    expect(voided.to_h.fetch(:substatus)).to eq(:canceled)
    expect(voided.to_h.fetch(:voidable)).to eq(false)
  end

  it "supports real sdk create flows for companies, products, plans, invoices, and payments" do
    session = WhopMock.start

    client = build_client
    WhopMock.install!(client)

    company = client.companies.create(title: "Acme", description: "Creator tools")
    expect(company).to be_a(WhopSDK::Company)
    expect(company.to_h.fetch(:id)).to start_with("biz_")
    expect(company.to_h.fetch(:title)).to eq("Acme")

    product = client.products.create(company_id: company.id, title: "Starter")
    expect(product).to be_a(WhopSDK::Product)
    expect(product.to_h.fetch(:company_id)).to eq(company.id)
    expect(product.to_h.fetch(:title)).to eq("Starter")

    plan = client.plans.create(company_id: company.id, product_id: product.id, title: "Monthly", renewal_price: 10.0)
    expect(plan).to be_a(WhopSDK::Plan)
    expect(plan.to_h.fetch(:company_id)).to eq(company.id)
    expect(plan.to_h.fetch(:product_id)).to eq(product.id)
    expect(plan.to_h.fetch(:title)).to eq("Monthly")

    invoice = client.invoices.create(
      body: {
        collection_method: :send_invoice,
        company_id: company.id,
        product: { title: "Invoice Product" },
        plan: { title: "Invoice Plan" },
        customer_name: "Test User",
        email_address: "user@example.com",
        save_as_draft: true
      }
    )
    expect(invoice).to be_a(WhopSDK::Invoice)
    expect(invoice.to_h.fetch(:company_id)).to eq(company.id)
    expect(invoice.to_h.fetch(:email_address)).to eq("user@example.com")

    payment = client.payments.create(
      body: {
        company_id: company.id,
        member_id: "mb_create_1",
        payment_method_id: "pmt_method_create_1",
        plan: {
          currency: :usd,
          title: "Payment Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_create_1",
            title: "Checkout Product"
          }
        }
      }
    )
    expect(payment).to be_a(WhopSDK::Payment)
    expect(payment.to_h.fetch(:company_id)).to eq(company.id)
    expect(payment.to_h.fetch(:plan_id)).to start_with("plan_")
    expect(payment.to_h.fetch(:product_id)).to start_with("prod_")
    expect(payment.to_h.fetch(:membership_id)).to start_with("mem_")
    expect(payment.to_h.fetch(:invoice_id)).to start_with("inv_")
    expect(payment.to_h.fetch(:currency)).to eq(:usd)
    expect(payment.to_h.fetch(:payment_method_id)).to eq("pmt_method_create_1")
    expect(payment.member.id).to eq("mb_create_1")
    expect(payment.user.id).to eq("mb_create_1")
    expect(session.store.find("product", payment.to_h.fetch(:product_id)).fetch("company_id")).to eq(company.id)
    expect(session.store.find("plan",
                              payment.to_h.fetch(:plan_id)).fetch("product_id")).to eq(payment.to_h.fetch(:product_id))

    membership = client.memberships.retrieve(payment.to_h.fetch(:membership_id))
    expect(membership).to be_a(WhopSDK::Membership)
    expect(membership.to_h.fetch(:status)).to eq(:active)
    expect(membership.to_h.fetch(:company_id)).to eq(company.id)
    expect(membership.plan.id).to eq(payment.to_h.fetch(:plan_id))
    expect(membership.product.id).to eq(payment.to_h.fetch(:product_id))
    expect(membership.user.id).to eq("mb_create_1")

    generated_invoice = client.invoices.retrieve(payment.to_h.fetch(:invoice_id))
    expect(generated_invoice).to be_a(WhopSDK::Invoice)
    expect(generated_invoice.to_h.fetch(:company_id)).to eq(company.id)
    expect(generated_invoice.to_h.fetch(:payment_id)).to eq(payment.id)
    expect(generated_invoice.to_h.fetch(:product_id)).to eq(payment.to_h.fetch(:product_id))
    expect(generated_invoice.to_h.fetch(:plan_id)).to eq(payment.to_h.fetch(:plan_id))
    expect(generated_invoice.user.id).to eq("mb_create_1")

    expect(session.store.list("plan").length).to be >= 2
    expect(session.store.list("product").length).to be >= 2
  end

  it "preserves rich linked graph state across sdk-first create flows and follow-on reads" do
    WhopMock.start

    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_graph_sdk",
        member_id: "mb_graph_sdk",
        payment_method_id: "pmt_method_graph_sdk",
        plan: {
          currency: :usd,
          title: "Graph Plan",
          renewal_price: 15.0,
          product: {
            external_identifier: "ext_graph_1",
            title: "Graph Product"
          }
        }
      }
    )

    payment_payload = client.payments.retrieve(payment.id).to_h
    invoice_payload = client.invoices.retrieve(payment_payload.fetch(:invoice_id)).to_h
    membership_payload = client.memberships.retrieve(payment_payload.fetch(:membership_id)).to_h

    expect(payment_payload.fetch(:company_id)).to eq("biz_graph_sdk")
    expect(client.payments.retrieve(payment.id).user.email).to eq("mb_graph_sdk@example.com")
    expect(client.payments.retrieve(payment.id).product.id).to eq(invoice_payload.fetch(:product_id))
    expect(client.payments.retrieve(payment.id).plan.id).to eq(invoice_payload.fetch(:plan_id))
    expect(invoice_payload.fetch(:company_id)).to eq("biz_graph_sdk")
    expect(client.invoices.retrieve(payment_payload.fetch(:invoice_id)).user.id).to eq("mb_graph_sdk")
    expect(membership_payload.fetch(:company_id)).to eq("biz_graph_sdk")
    expect(client.memberships.retrieve(payment_payload.fetch(:membership_id)).user.id).to eq("mb_graph_sdk")

    payment_ids = []
    client.payments.list(company_id: "biz_graph_sdk", query: "mb_graph_sdk@example.com", first: 10)
          .auto_paging_each { |item| payment_ids << item.to_h.fetch(:id) }
    expect(payment_ids).to include(payment.id)

    event = WhopMock.mock_webhook_event("payment.succeeded", data: { id: payment.id })
    expect(event.fetch("company_id")).to eq("biz_graph_sdk")
    expect(event.dig("data", "invoice", "id")).to eq(invoice_payload.fetch(:id))
    expect(event.dig("data", "membership", "id")).to eq(membership_payload.fetch(:id))
  end

  it "surfaces refund side effects through the real sdk" do
    client = build_client
    WhopMock.install!(client, spec_path: File.expand_path("fixtures/openapi.yml", __dir__))

    payment = client.payments.create(
      body: {
        company_id: "biz_refund_sdk",
        member_id: "mb_refund_sdk",
        payment_method_id: "pmt_method_refund_sdk",
        plan: {
          currency: :usd,
          title: "Refundable Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_refund_1",
            title: "Refund Product"
          }
        }
      }
    )

    refunded = client.payments.refund(payment.id)
    expect(refunded.to_h.fetch(:substatus)).to eq(:refunded)
    expect(refunded.to_h.fetch(:refunded_amount)).to eq(10.0)

    refunds = []
    client.refunds.list(first: 10).auto_paging_each { |item| refunds << item.to_h.fetch(:id) }
    expect(refunds.length).to eq(1)

    invoice = client.invoices.retrieve(payment.to_h.fetch(:invoice_id))
    expect(invoice.to_h.fetch(:status).to_s).to eq("refunded")
  end

  it "models partial refund lifecycle state through the real sdk" do
    session = WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_partial_sdk",
        member_id: "mb_partial_sdk",
        payment_method_id: "pmt_method_partial_sdk",
        plan: {
          currency: :usd,
          title: "Partial SDK Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_partial_1",
            title: "Partial SDK Product"
          }
        }
      }
    )

    partially_refunded = client.payments.refund(payment.id, partial_amount: 4.0)
    expect(partially_refunded.to_h.fetch(:substatus)).to eq(:partially_refunded)
    expect(partially_refunded.to_h.fetch(:refunded_amount)).to eq(4.0)
    expect(partially_refunded.to_h.fetch(:refundable)).to eq(true)

    invoice = client.invoices.retrieve(payment.to_h.fetch(:invoice_id))
    expect(invoice.to_h.fetch(:status)).to eq(:paid)

    membership = client.memberships.retrieve(payment.to_h.fetch(:membership_id))
    expect(membership.to_h.fetch(:status)).to eq(:active)

    refund = session.store.list("refund").max_by { |record| record["created_at"].to_s }
    refund_event = WhopMock.mock_webhook_event("refund.updated", data: { id: refund.fetch("id") })
    expect(refund_event.fetch("company_id")).to eq("biz_partial_sdk")
    expect(refund_event.dig("data", "amount")).to eq(4.0)

    webhook_client = build_client(webhook_key: WhopMock.sign_webhook({}, secret: "test_partial_secret").fetch("secret"))
    signed = WhopMock.sign_webhook(refund_event, secret: webhook_client.webhook_key, webhook_id: "msg_partial_refund",
                                                 timestamp: Time.now.to_i)
    unwrapped = webhook_client.webhooks.unwrap(signed.fetch("payload"), headers: signed.fetch("headers"))
    expect(unwrapped).to be_a(WhopSDK::Models::RefundUpdatedWebhookEvent)
    expect(unwrapped.data.amount).to eq(4.0)
  end

  it "supports repeated partial refunds, list filtering, and final full-refund transition through the real sdk" do
    session = WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_multi_partial_sdk",
        member_id: "mb_multi_partial_sdk",
        payment_method_id: "pmt_method_multi_partial_sdk",
        plan: {
          currency: :usd,
          title: "Multi Partial SDK Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_multi_partial_1",
            title: "Multi Partial SDK Product"
          }
        }
      }
    )

    first_refund = client.payments.refund(payment.id, partial_amount: 3.0)
    expect(first_refund.to_h.fetch(:substatus)).to eq(:partially_refunded)
    expect(first_refund.to_h.fetch(:refunded_amount)).to eq(3.0)
    expect(client.invoices.retrieve(payment.to_h.fetch(:invoice_id)).to_h.fetch(:status)).to eq(:paid)
    expect(client.memberships.retrieve(payment.to_h.fetch(:membership_id)).to_h.fetch(:status)).to eq(:active)

    partially_refunded_ids = []
    client.payments.list(company_id: "biz_multi_partial_sdk", substatuses: [:partially_refunded], first: 10)
          .auto_paging_each { |item| partially_refunded_ids << item.to_h.fetch(:id) }
    expect(partially_refunded_ids).to include(payment.id)

    first_refund_record = session.store.list("refund").last
    partial_event = WhopMock.mock_webhook_event("refund.updated", data: { id: first_refund_record.fetch("id") })
    expect(partial_event.fetch("company_id")).to eq("biz_multi_partial_sdk")
    expect(partial_event.dig("data", "amount")).to eq(3.0)

    second_refund = client.payments.refund(payment.id, partial_amount: 7.0)
    expect(second_refund.to_h.fetch(:substatus)).to eq(:refunded)
    expect(second_refund.to_h.fetch(:refunded_amount)).to eq(10.0)
    expect(second_refund.to_h.fetch(:refundable)).to eq(false)
    expect(client.invoices.retrieve(payment.to_h.fetch(:invoice_id)).to_h.fetch(:status).to_s).to eq("refunded")
    expect(client.memberships.retrieve(payment.to_h.fetch(:membership_id)).to_h.fetch(:status)).to eq(:canceled)

    second_refund_record = session.store.list("refund").last
    final_refund_event = WhopMock.mock_webhook_event("refund.updated", data: { id: second_refund_record.fetch("id") })
    final_payment_event = WhopMock.mock_webhook_event("payment.refunded", data: { id: payment.id })
    expect(final_refund_event.dig("data", "amount")).to eq(7.0)
    expect(final_payment_event.dig("data", "substatus")).to eq("refunded")

    webhook_client = build_client(webhook_key: WhopMock.sign_webhook({},
                                                                     secret: "test_multi_partial_secret").fetch("secret"))
    signed_partial = WhopMock.sign_webhook(partial_event, secret: webhook_client.webhook_key,
                                                          webhook_id: "msg_multi_partial_first", timestamp: Time.now.to_i)
    unwrapped_partial = webhook_client.webhooks.unwrap(signed_partial.fetch("payload"),
                                                       headers: signed_partial.fetch("headers"))
    expect(unwrapped_partial).to be_a(WhopSDK::Models::RefundUpdatedWebhookEvent)
    expect(unwrapped_partial.data.amount).to eq(3.0)

    signed_final = WhopMock.sign_webhook(final_refund_event, secret: webhook_client.webhook_key,
                                                             webhook_id: "msg_multi_partial_final", timestamp: Time.now.to_i)
    unwrapped_final = webhook_client.webhooks.unwrap(signed_final.fetch("payload"),
                                                     headers: signed_final.fetch("headers"))
    expect(unwrapped_final).to be_a(WhopSDK::Models::RefundUpdatedWebhookEvent)
    expect(unwrapped_final.data.amount).to eq(7.0)
  end

  it "supports sdk create variants that reference existing plan and product ids" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_existing_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product",
                         product_record(id: "prod_existing_sdk", company_id: "biz_existing_sdk",
                                        created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("plan", plan_record(id: "plan_existing_sdk", company_id: "biz_existing_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_existing_sdk",
                                   "product" => { "id" => "prod_existing_sdk", "title" => "Starter" },
                                   "currency" => "usd",
                                   "renewal_price" => 10.0
                                 ))

    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_existing_sdk",
        member_id: "mb_existing_sdk",
        payment_method_id: "pmt_method_existing_sdk",
        plan_id: "plan_existing_sdk"
      }
    )
    expect(payment.to_h.fetch(:plan_id)).to eq("plan_existing_sdk")
    expect(payment.to_h.fetch(:product_id)).to eq("prod_existing_sdk")

    invoice = client.invoices.create(
      body: {
        collection_method: :send_invoice,
        company_id: "biz_existing_sdk",
        product_id: "prod_existing_sdk",
        plan: { title: "Invoice Variant Plan", renewal_price: 15.0 },
        customer_name: "Existing User",
        email_address: "user@example.com",
        save_as_draft: true
      }
    )
    expect(invoice.to_h.fetch(:status).to_s).to eq("draft")
    expect(invoice.to_h.fetch(:product_id)).to eq("prod_existing_sdk")
    expect(invoice.current_plan.id).to start_with("plan_")
  end

  it "supports sparse payment and invoice create variants with existing ids and generated defaults" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_sparse_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_sparse_sdk", company_id: "biz_sparse_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Existing Sparse Product"
                                    ))

    client = build_client
    WhopMock.install!(client)

    sparse_payment = client.payments.create(
      body: {
        company_id: "biz_sparse_sdk",
        member_id: "mb_sparse_sdk",
        payment_method_id: "pmt_method_sparse_sdk",
        plan: {
          currency: :usd,
          product_id: "prod_sparse_sdk"
        }
      }
    )

    expect(sparse_payment.to_h.fetch(:company_id)).to eq("biz_sparse_sdk")
    expect(sparse_payment.to_h.fetch(:product_id)).to eq("prod_sparse_sdk")
    expect(sparse_payment.to_h.fetch(:plan_id)).to start_with("plan_")
    expect(client.payments.retrieve(sparse_payment.id).user.email).to eq("mb_sparse_sdk@example.com")
    expect(session.store.find("plan", sparse_payment.to_h.fetch(:plan_id)).fetch("product_id")).to eq("prod_sparse_sdk")

    sparse_invoice = client.invoices.create(
      body: {
        collection_method: :send_invoice,
        company_id: "biz_sparse_sdk",
        member_id: "mb_sparse_invoice_sdk",
        product_id: "prod_sparse_sdk",
        plan: {},
        save_as_draft: true
      }
    )

    expect(sparse_invoice.to_h.fetch(:company_id)).to eq("biz_sparse_sdk")
    expect(sparse_invoice.to_h.fetch(:product_id)).to eq("prod_sparse_sdk")
    expect(sparse_invoice.to_h.fetch(:status).to_s).to eq("draft")
    expect(sparse_invoice.user.id).to eq("mb_sparse_invoice_sdk")
    expect(sparse_invoice.to_h.fetch(:email_address)).to eq("mb_sparse_invoice_sdk@example.com")
    expect(sparse_invoice.current_plan.id).to start_with("plan_")
    expect(session.store.find("plan", sparse_invoice.current_plan.id).fetch("product_id")).to eq("prod_sparse_sdk")
  end

  it "supports invoice create variants with member, token, charge_automatically, and due-date semantics" do
    session = WhopMock.start
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")
    session.store.insert("company", company_record(id: "biz_invoice_variant_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_invoice_variant_sdk", company_id: "biz_invoice_variant_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Invoice Variant Product"
                                    ))

    client = build_client
    WhopMock.install!(client)

    invoice = client.invoices.create(
      body: {
        collection_method: :charge_automatically,
        company_id: "biz_invoice_variant_sdk",
        member_id: "mb_invoice_variant_sdk",
        payment_token_id: token.fetch("id"),
        product_id: "prod_invoice_variant_sdk",
        plan: {},
        due_date: "2026-05-09T10:00:00Z",
        save_as_draft: true
      }
    )

    expect(invoice.to_h.fetch(:status).to_s).to eq("draft")
    expect(invoice.to_h.fetch(:due_date)).to eq("2026-05-09T10:00:00Z")
    expect(invoice.user.id).to eq("mb_invoice_variant_sdk")
    expect(invoice.to_h.fetch(:email_address)).to eq("mb_invoice_variant_sdk@example.com")
    expect(invoice.current_plan.id).to start_with("plan_")

    stored = session.store.find("invoice", invoice.id)
    expect(stored.fetch("collection_method")).to eq("charge_automatically")
    expect(stored.fetch("payment_token_id")).to eq(token.fetch("id"))
    expect(stored.fetch("member_id")).to eq("mb_invoice_variant_sdk")
    expect(session.store.find("plan", invoice.current_plan.id).fetch("product_id")).to eq("prod_invoice_variant_sdk")

    draft_ids = []
    client.invoices.list(
      company_id: "biz_invoice_variant_sdk",
      statuses: [:draft],
      created_after: "2026-04-01T00:00:00Z",
      order: :due_date,
      direction: :asc,
      first: 10
    ).auto_paging_each { |item| draft_ids << item.id }
    expect(draft_ids).to include(invoice.id)
  end

  it "keeps overlapping draft and paid invoice loops isolated for the same member" do
    session = WhopMock.start
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")
    session.store.insert("company", company_record(id: "biz_invoice_overlap_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_invoice_overlap_sdk", company_id: "biz_invoice_overlap_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Overlap Invoice Product"
                                    ))

    client = build_client
    WhopMock.install!(client)

    first_invoice = client.invoices.create(
      body: {
        collection_method: :charge_automatically,
        company_id: "biz_invoice_overlap_sdk",
        member_id: "mb_invoice_overlap_sdk",
        payment_token_id: token.fetch("id"),
        product_id: "prod_invoice_overlap_sdk",
        plan: {},
        due_date: "2026-05-20T10:00:00Z",
        save_as_draft: true
      }
    )
    second_invoice = client.invoices.create(
      body: {
        collection_method: :charge_automatically,
        company_id: "biz_invoice_overlap_sdk",
        member_id: "mb_invoice_overlap_sdk",
        payment_token_id: token.fetch("id"),
        product_id: "prod_invoice_overlap_sdk",
        plan: {},
        due_date: "2026-05-10T10:00:00Z",
        save_as_draft: true
      }
    )

    expect(first_invoice.user.id).to eq("mb_invoice_overlap_sdk")
    expect(second_invoice.user.id).to eq("mb_invoice_overlap_sdk")
    expect(first_invoice.current_plan.id).not_to eq(second_invoice.current_plan.id)

    updated_first_invoice = client.invoices.update(
      first_invoice.id,
      email_address: "first-updated@example.com",
      plan: {
        title: "Overlap Draft Plan",
        renewal_price: 42.0,
        currency: :usd
      }
    )
    expect(updated_first_invoice.to_h.fetch(:status).to_s).to eq("draft")
    expect(updated_first_invoice.current_plan.formatted_price).to eq("$42.00")

    expect(client.invoices.mark_paid(second_invoice.id)).to eq(true)
    paid_second_invoice = client.invoices.retrieve(second_invoice.id)
    expect(paid_second_invoice.to_h.fetch(:status).to_s).to eq("paid")

    third_invoice = client.invoices.create(
      body: {
        collection_method: :send_invoice,
        company_id: "biz_invoice_overlap_sdk",
        member_id: "mb_invoice_overlap_sdk",
        product_id: "prod_invoice_overlap_sdk",
        plan: {},
        due_date: "2026-05-05T10:00:00Z",
        save_as_draft: true
      }
    )

    reloaded_first_invoice = client.invoices.retrieve(first_invoice.id)
    reloaded_third_invoice = client.invoices.retrieve(third_invoice.id)
    expect(reloaded_first_invoice.to_h.fetch(:status).to_s).to eq("draft")
    expect(reloaded_first_invoice.to_h.fetch(:email_address)).to eq("first-updated@example.com")
    expect(reloaded_third_invoice.to_h.fetch(:status).to_s).to eq("draft")
    expect(reloaded_third_invoice.user.id).to eq("mb_invoice_overlap_sdk")

    expect(session.store.find("plan", first_invoice.current_plan.id).fetch("renewal_price")).to eq(42.0)
    expect(session.store.find("plan", second_invoice.current_plan.id).fetch("renewal_price")).not_to eq(42.0)
    expect(session.store.find("plan",
                              third_invoice.current_plan.id).fetch("product_id")).to eq("prod_invoice_overlap_sdk")

    draft_ids = []
    client.invoices.list(
      company_id: "biz_invoice_overlap_sdk",
      statuses: [:draft],
      order: :due_date,
      direction: :asc,
      first: 10
    ).auto_paging_each { |item| draft_ids << item.id }
    expect(draft_ids).to eq([third_invoice.id, first_invoice.id])
  end

  it "preserves metadata and graph reuse across repeated payment creates against an existing plan" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_reuse_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_reuse_sdk", company_id: "biz_reuse_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Reuse Product"
                                    ))
    session.store.insert("plan", plan_record(id: "plan_reuse_sdk", company_id: "biz_reuse_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_reuse_sdk",
                                   "product" => { "id" => "prod_reuse_sdk", "title" => "Reuse Product" },
                                   "currency" => "usd",
                                   "renewal_price" => 25.0,
                                   "title" => "Reuse Plan"
                                 ))

    client = build_client
    WhopMock.install!(client)

    first_payment = client.payments.create(
      body: {
        company_id: "biz_reuse_sdk",
        member_id: "mb_reuse_sdk_1",
        payment_method_id: "pmt_method_reuse_sdk_1",
        plan_id: "plan_reuse_sdk",
        metadata: { order_id: "order_1", cohort: "alpha" }
      }
    )
    second_payment = client.payments.create(
      body: {
        company_id: "biz_reuse_sdk",
        member_id: "mb_reuse_sdk_2",
        payment_method_id: "pmt_method_reuse_sdk_2",
        plan_id: "plan_reuse_sdk",
        metadata: { order_id: "order_2", cohort: "beta" }
      }
    )

    expect(first_payment.to_h.fetch(:plan_id)).to eq("plan_reuse_sdk")
    expect(second_payment.to_h.fetch(:plan_id)).to eq("plan_reuse_sdk")
    expect(first_payment.to_h.fetch(:product_id)).to eq("prod_reuse_sdk")
    expect(second_payment.to_h.fetch(:product_id)).to eq("prod_reuse_sdk")
    expect(first_payment.metadata[:order_id]).to eq("order_1")
    expect(second_payment.metadata[:order_id]).to eq("order_2")

    expect(client.invoices.retrieve(first_payment.to_h.fetch(:invoice_id)).to_h.fetch(:plan_id)).to eq("plan_reuse_sdk")
    expect(client.invoices.retrieve(second_payment.to_h.fetch(:invoice_id)).to_h.fetch(:plan_id)).to eq("plan_reuse_sdk")
    expect(client.memberships.retrieve(first_payment.to_h.fetch(:membership_id)).plan.id).to eq("plan_reuse_sdk")
    expect(client.memberships.retrieve(second_payment.to_h.fetch(:membership_id)).product.id).to eq("prod_reuse_sdk")

    payment_ids = []
    client.payments.list(company_id: "biz_reuse_sdk", plan_ids: ["plan_reuse_sdk"], product_ids: ["prod_reuse_sdk"],
                         first: 10)
          .auto_paging_each do |item|
      payment_ids << item.to_h.fetch(:id)
    end
    expect(payment_ids).to include(first_payment.id, second_payment.id)

    expect(session.store.list("plan").count { |record| record["id"] == "plan_reuse_sdk" }).to eq(1)
    expect(session.store.find("payment", first_payment.id).fetch("metadata").fetch("cohort")).to eq("alpha")
    expect(session.store.find("payment", second_payment.id).fetch("metadata").fetch("cohort")).to eq("beta")
  end

  it "reuses existing payment methods and supports metadata and payment-method search stress across repeated creates" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_method_reuse_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_method_reuse_sdk", company_id: "biz_method_reuse_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Method Reuse Product"
                                    ))
    session.store.insert("plan", plan_record(id: "plan_method_reuse_sdk", company_id: "biz_method_reuse_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_method_reuse_sdk",
                                   "product" => { "id" => "prod_method_reuse_sdk", "title" => "Method Reuse Product" },
                                   "currency" => "usd",
                                   "renewal_price" => 30.0,
                                   "title" => "Method Reuse Plan"
                                 ))
    session.store.insert("payment_method", payment_method_record(id: "pmt_method_reuse_existing_sdk", created_at: "2026-04-29T10:00:00Z", last4: "4242").merge(
                                             "payment_method_type" => "card"
                                           ))

    client = build_client
    WhopMock.install!(client)

    first_payment = client.payments.create(
      body: {
        company_id: "biz_method_reuse_sdk",
        member_id: "mb_method_reuse_sdk_1",
        payment_method_id: "pmt_method_reuse_existing_sdk",
        plan_id: "plan_method_reuse_sdk",
        metadata: {
          order_id: "order_pm_1",
          campaign: "spring-launch",
          tags: %w[vip creator]
        }
      }
    )
    second_payment = client.payments.create(
      body: {
        company_id: "biz_method_reuse_sdk",
        member_id: "mb_method_reuse_sdk_2",
        payment_method_id: "pmt_method_reuse_existing_sdk",
        plan_id: "plan_method_reuse_sdk",
        metadata: {
          order_id: "order_pm_2",
          campaign: "summer-launch",
          nested: { cohort: "beta" }
        }
      }
    )

    expect(first_payment.to_h.fetch(:payment_method_id)).to eq("pmt_method_reuse_existing_sdk")
    expect(second_payment.to_h.fetch(:payment_method_id)).to eq("pmt_method_reuse_existing_sdk")
    expect(first_payment.payment_method.id).to eq("pmt_method_reuse_existing_sdk")
    expect(second_payment.payment_method.id).to eq("pmt_method_reuse_existing_sdk")
    expect(first_payment.payment_method.card.last4).to eq("4242")
    expect(second_payment.payment_method.card.last4).to eq("4242")
    expect(first_payment.metadata[:campaign]).to eq("spring-launch")
    expect(second_payment.metadata[:campaign]).to eq("summer-launch")

    stored_payment_method_ids = session.store.list("payment_method").map { |record| record["id"] }
    expect(stored_payment_method_ids.count("pmt_method_reuse_existing_sdk")).to eq(1)

    metadata_ids = []
    client.payments.list(company_id: "biz_method_reuse_sdk", query: "spring-launch", first: 10)
          .auto_paging_each { |item| metadata_ids << item.id }
    expect(metadata_ids).to eq([first_payment.id])

    nested_metadata_ids = []
    client.payments.list(company_id: "biz_method_reuse_sdk", query: "beta", first: 10)
          .auto_paging_each { |item| nested_metadata_ids << item.id }
    expect(nested_metadata_ids).to eq([second_payment.id])

    payment_method_ids = []
    client.payments.list(company_id: "biz_method_reuse_sdk", query: "4242", first: 10)
          .auto_paging_each { |item| payment_method_ids << item.id }
    expect(payment_method_ids).to include(first_payment.id, second_payment.id)

    stored_first = session.store.find("payment", first_payment.id)
    stored_second = session.store.find("payment", second_payment.id)
    expect(stored_first.fetch("metadata").fetch("tags")).to eq(%w[vip creator])
    expect(stored_second.fetch("metadata").fetch("nested").fetch("cohort")).to eq("beta")
    expect(stored_first.dig("payment_method", "last4")).to eq("4242")
    expect(stored_second.dig("payment_method", "brand")).to eq("visa")
  end

  it "couples refund, invoice, payment, and membership lifecycle state through the real sdk" do
    session = WhopMock.start

    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_lifecycle_sdk",
        member_id: "mb_lifecycle_sdk",
        payment_method_id: "pmt_method_lifecycle_sdk",
        plan: {
          currency: :usd,
          title: "Lifecycle Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_lifecycle_1",
            title: "Lifecycle Product"
          }
        }
      }
    )

    membership_id = payment.to_h.fetch(:membership_id)
    invoice_id = payment.to_h.fetch(:invoice_id)

    refunded = client.payments.refund(payment.id)
    expect(refunded.to_h.fetch(:substatus)).to eq(:refunded)

    refunded_membership = client.memberships.retrieve(membership_id)
    expect(refunded_membership.to_h.fetch(:status).to_s).to eq("canceled")
    expect(refunded_membership.canceled_at).not_to be_nil

    refunded_invoice = client.invoices.retrieve(invoice_id)
    expect(refunded_invoice.to_h.fetch(:status).to_s).to eq("refunded")

    session.store.update("payment", payment.id, "status" => "open", "substatus" => "pending")
    session.store.update("invoice", invoice_id, "status" => "open")
    session.store.update("membership", membership_id, "status" => "active", "payment_collection_paused" => true)

    expect(client.invoices.mark_paid(invoice_id)).to eq(true)

    paid_payment = client.payments.retrieve(payment.id)
    expect(paid_payment.to_h.fetch(:status).to_s).to eq("paid")
    expect(paid_payment.to_h.fetch(:substatus).to_s).to eq("succeeded")

    paid_membership = client.memberships.retrieve(membership_id)
    expect(paid_membership.to_h.fetch(:status).to_s).to eq("active")
    expect(paid_membership.to_h.fetch(:payment_collection_paused)).to eq(false)

    expect(client.invoices.void(invoice_id)).to eq(true)

    voided_payment = client.payments.retrieve(payment.id)
    expect(voided_payment.to_h.fetch(:status).to_s).to eq("void")
    expect(voided_payment.to_h.fetch(:substatus).to_s).to eq("canceled")

    voided_membership = client.memberships.retrieve(membership_id)
    expect(voided_membership.to_h.fetch(:status).to_s).to eq("canceled")
    expect(voided_membership.canceled_at).not_to be_nil
  end

  it "couples draft invoice updates with failed and retried billing state through the real sdk" do
    session = WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_draft_sdk",
        member_id: "mb_draft_sdk",
        payment_method_id: "pmt_method_draft_sdk",
        plan: {
          currency: :usd,
          title: "Draftable Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_draft_1",
            title: "Draftable Product"
          }
        }
      }
    )

    invoice_id = payment.to_h.fetch(:invoice_id)
    membership_id = payment.to_h.fetch(:membership_id)
    session.store.update("invoice", invoice_id, "status" => "draft")

    updated_invoice = client.invoices.update(
      invoice_id,
      email_address: "updated@example.com",
      plan: {
        title: "Updated Draft Plan",
        renewal_price: 25.0,
        currency: :usd
      }
    )
    expect(updated_invoice.to_h.fetch(:email_address)).to eq("updated@example.com")
    expect(updated_invoice.current_plan.formatted_price).to eq("$25.00")
    expect(session.store.find("plan", updated_invoice.current_plan.id).fetch("renewal_price")).to eq(25.0)

    expect(client.invoices.mark_uncollectible(invoice_id)).to eq(true)

    failed_payment = client.payments.retrieve(payment.id)
    expect(failed_payment.to_h.fetch(:substatus).to_s).to eq("failed")

    paused_membership = client.memberships.retrieve(membership_id)
    expect(paused_membership.to_h.fetch(:status).to_s).to eq("active")
    expect(paused_membership.to_h.fetch(:payment_collection_paused)).to eq(true)

    retried = client.payments.retry_(payment.id)
    expect(retried.to_h.fetch(:status).to_s).to eq("pending")

    reopened_invoice = client.invoices.retrieve(invoice_id)
    expect(reopened_invoice.to_h.fetch(:status).to_s).to eq("open")

    reactivated_membership = client.memberships.retrieve(membership_id)
    expect(reactivated_membership.to_h.fetch(:status).to_s).to eq("active")
    expect(reactivated_membership.to_h.fetch(:payment_collection_paused)).to eq(false)
  end

  it "fabricates lifecycle webhook families from sdk-created billing graphs" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_lifecycle_hooks",
        member_id: "mb_lifecycle_hooks",
        payment_method_id: "pmt_method_lifecycle_hooks",
        plan: {
          currency: :usd,
          title: "Lifecycle Hooks Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_lifecycle_hooks_1",
            title: "Lifecycle Hooks Product"
          }
        }
      }
    )

    invoice_id = payment.to_h.fetch(:invoice_id)
    membership_id = payment.to_h.fetch(:membership_id)

    expect(client.invoices.mark_uncollectible(invoice_id)).to eq(true)

    uncollectible_event = WhopMock.mock_webhook_event("invoice.marked_uncollectible", data: { id: invoice_id })
    expect(uncollectible_event.fetch("company_id")).to eq("biz_lifecycle_hooks")
    expect(uncollectible_event.dig("data", "status")).to eq("uncollectible")
    expect(uncollectible_event.dig("data", "payment", "id")).to eq(payment.id)
    expect(uncollectible_event.dig("data", "payment", "substatus")).to eq("failed")

    pending_payment = client.payments.retry_(payment.id)
    pending_event = WhopMock.mock_webhook_event("payment.pending", data: { id: payment.id })
    expect(pending_payment.to_h.fetch(:status)).to eq(:pending)
    expect(pending_event.fetch("company_id")).to eq("biz_lifecycle_hooks")
    expect(pending_event.dig("data", "status")).to eq("pending")
    expect(pending_event.dig("data", "invoice", "id")).to eq(invoice_id)

    expect(client.payments.void(payment.id).to_h.fetch(:status)).to eq(:void)
    deactivated_event = WhopMock.mock_webhook_event("membership.deactivated", data: { id: membership_id })
    expect(deactivated_event.fetch("company_id")).to eq("biz_lifecycle_hooks")
    expect(deactivated_event.dig("data", "status")).to eq("canceled")
    expect(deactivated_event.dig("data", "payment", "id")).to eq(payment.id)
    expect(deactivated_event.dig("data", "invoice", "id")).to eq(invoice_id)
  end

  it "unwraps supported lifecycle webhook events from sdk-created graphs" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_unwrap_lifecycle",
        member_id: "mb_unwrap_lifecycle",
        payment_method_id: "pmt_method_unwrap_lifecycle",
        plan: {
          currency: :usd,
          title: "Unwrap Lifecycle Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_unwrap_lifecycle_1",
            title: "Unwrap Lifecycle Product"
          }
        }
      }
    )

    invoice_id = payment.to_h.fetch(:invoice_id)
    membership_id = payment.to_h.fetch(:membership_id)

    expect(client.invoices.mark_uncollectible(invoice_id)).to eq(true)
    expect(client.payments.retry_(payment.id).to_h.fetch(:status)).to eq(:pending)
    expect(client.payments.void(payment.id).to_h.fetch(:status)).to eq(:void)

    webhook_client = build_client(webhook_key: WhopMock.sign_webhook({}, secret: "test_webhook_secret").fetch("secret"))

    invoice_event = WhopMock.mock_webhook_event("invoice.marked_uncollectible", data: { id: invoice_id })
    signed_invoice = WhopMock.sign_webhook(invoice_event, secret: webhook_client.webhook_key,
                                                          webhook_id: "msg_invoice_lifecycle", timestamp: Time.now.to_i)
    unwrapped_invoice = webhook_client.webhooks.unwrap(signed_invoice.fetch("payload"),
                                                       headers: signed_invoice.fetch("headers"))
    expect(unwrapped_invoice).to be_a(WhopSDK::Models::InvoiceMarkedUncollectibleWebhookEvent)
    expect(unwrapped_invoice.data.id).to eq(invoice_id)

    payment_event = WhopMock.mock_webhook_event("payment.pending", data: { id: payment.id })
    signed_payment = WhopMock.sign_webhook(payment_event, secret: webhook_client.webhook_key,
                                                          webhook_id: "msg_payment_lifecycle", timestamp: Time.now.to_i)
    unwrapped_payment = webhook_client.webhooks.unwrap(signed_payment.fetch("payload"),
                                                       headers: signed_payment.fetch("headers"))
    expect(unwrapped_payment).to be_a(WhopSDK::Models::PaymentPendingWebhookEvent)
    expect(unwrapped_payment.data.id).to eq(payment.id)

    membership_event = WhopMock.mock_webhook_event("membership.deactivated", data: { id: membership_id })
    signed_membership = WhopMock.sign_webhook(membership_event, secret: webhook_client.webhook_key,
                                                                webhook_id: "msg_membership_lifecycle", timestamp: Time.now.to_i)
    unwrapped_membership = webhook_client.webhooks.unwrap(signed_membership.fetch("payload"),
                                                          headers: signed_membership.fetch("headers"))
    expect(unwrapped_membership).to be_a(WhopSDK::Models::MembershipDeactivatedWebhookEvent)
    expect(unwrapped_membership.data.id).to eq(membership_id)
  end

  it "unwraps broader supported webhook union events across billing lifecycles" do
    session = WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_union_hooks",
        member_id: "mb_union_hooks",
        payment_method_id: "pmt_method_union_hooks",
        plan: {
          currency: :usd,
          title: "Union Hooks Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_union_hooks_1",
            title: "Union Hooks Product"
          }
        }
      }
    )

    invoice_id = payment.to_h.fetch(:invoice_id)
    expect(client.invoices.mark_uncollectible(invoice_id)).to eq(true)
    failed_event = WhopMock.mock_webhook_event("payment.failed", data: { id: payment.id })

    refunding_payment = client.payments.create(
      body: {
        company_id: "biz_union_refund",
        member_id: "mb_union_refund",
        payment_method_id: "pmt_method_union_refund",
        plan: {
          currency: :usd,
          title: "Union Refund Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_union_refund_1",
            title: "Union Refund Product"
          }
        }
      }
    )
    client.payments.refund(refunding_payment.id)
    refund = session.store.list("refund").max_by { |record| record["created_at"].to_s }
    refund_created_event = WhopMock.mock_webhook_event("refund.created", data: { id: refund.fetch("id") })
    refund_updated_event = WhopMock.mock_webhook_event("refund.updated", data: { id: refund.fetch("id") })

    voidable_payment = client.payments.create(
      body: {
        company_id: "biz_union_void",
        member_id: "mb_union_void",
        payment_method_id: "pmt_method_union_void",
        plan: {
          currency: :usd,
          title: "Union Void Plan",
          renewal_price: 10.0,
          product: {
            external_identifier: "ext_union_void_1",
            title: "Union Void Product"
          }
        }
      }
    )
    expect(client.invoices.void(voidable_payment.to_h.fetch(:invoice_id))).to eq(true)
    voided_event = WhopMock.mock_webhook_event("invoice.voided", data: { id: voidable_payment.to_h.fetch(:invoice_id) })

    session.store.insert("setup_intent",
                         setup_intent_record(id: "setup_union_1",
                                             company_id: "biz_setup_union").merge("status" => "requires_action"))
    setup_requires_action_event = WhopMock.mock_webhook_event("setup_intent.requires_action",
                                                              data: { id: "setup_union_1" })
    session.store.update("setup_intent", "setup_union_1", "status" => "canceled")
    setup_canceled_event = WhopMock.mock_webhook_event("setup_intent.canceled", data: { id: "setup_union_1" })
    session.store.update("setup_intent", "setup_union_1", "status" => "succeeded")
    setup_succeeded_event = WhopMock.mock_webhook_event("setup_intent.succeeded", data: { id: "setup_union_1" })

    webhook_client = build_client(webhook_key: WhopMock.sign_webhook({}, secret: "test_union_secret").fetch("secret"))

    signed_failed = WhopMock.sign_webhook(failed_event, secret: webhook_client.webhook_key,
                                                        webhook_id: "msg_union_failed", timestamp: Time.now.to_i)
    expect(webhook_client.webhooks.unwrap(signed_failed.fetch("payload"), headers: signed_failed.fetch("headers")))
      .to be_a(WhopSDK::Models::PaymentFailedWebhookEvent)

    signed_refund_created = WhopMock.sign_webhook(refund_created_event, secret: webhook_client.webhook_key,
                                                                        webhook_id: "msg_union_refund_created", timestamp: Time.now.to_i)
    unwrapped_refund_created = webhook_client.webhooks.unwrap(signed_refund_created.fetch("payload"),
                                                              headers: signed_refund_created.fetch("headers"))
    expect(unwrapped_refund_created).to be_a(WhopSDK::Models::RefundCreatedWebhookEvent)
    expect(unwrapped_refund_created.data.id).to eq(refund.fetch("id"))

    signed_refund_updated = WhopMock.sign_webhook(refund_updated_event, secret: webhook_client.webhook_key,
                                                                        webhook_id: "msg_union_refund_updated", timestamp: Time.now.to_i)
    unwrapped_refund_updated = webhook_client.webhooks.unwrap(signed_refund_updated.fetch("payload"),
                                                              headers: signed_refund_updated.fetch("headers"))
    expect(unwrapped_refund_updated).to be_a(WhopSDK::Models::RefundUpdatedWebhookEvent)
    expect(unwrapped_refund_updated.data.id).to eq(refund.fetch("id"))

    signed_voided = WhopMock.sign_webhook(voided_event, secret: webhook_client.webhook_key,
                                                        webhook_id: "msg_union_voided", timestamp: Time.now.to_i)
    unwrapped_voided = webhook_client.webhooks.unwrap(signed_voided.fetch("payload"),
                                                      headers: signed_voided.fetch("headers"))
    expect(unwrapped_voided).to be_a(WhopSDK::Models::InvoiceVoidedWebhookEvent)
    expect(unwrapped_voided.data.id).to eq(voidable_payment.to_h.fetch(:invoice_id))

    signed_requires_action = WhopMock.sign_webhook(setup_requires_action_event, secret: webhook_client.webhook_key,
                                                                                webhook_id: "msg_union_requires_action", timestamp: Time.now.to_i)
    expect(webhook_client.webhooks.unwrap(signed_requires_action.fetch("payload"),
                                          headers: signed_requires_action.fetch("headers")))
      .to be_a(WhopSDK::Models::SetupIntentRequiresActionWebhookEvent)

    signed_canceled = WhopMock.sign_webhook(setup_canceled_event, secret: webhook_client.webhook_key,
                                                                  webhook_id: "msg_union_canceled", timestamp: Time.now.to_i)
    expect(webhook_client.webhooks.unwrap(signed_canceled.fetch("payload"), headers: signed_canceled.fetch("headers")))
      .to be_a(WhopSDK::Models::SetupIntentCanceledWebhookEvent)

    signed_succeeded = WhopMock.sign_webhook(setup_succeeded_event, secret: webhook_client.webhook_key,
                                                                    webhook_id: "msg_union_succeeded", timestamp: Time.now.to_i)
    expect(webhook_client.webhooks.unwrap(signed_succeeded.fetch("payload"),
                                          headers: signed_succeeded.fetch("headers")))
      .to be_a(WhopSDK::Models::SetupIntentSucceededWebhookEvent)
  end

  it "unwraps broader typed webhook families beyond billing-heavy flows" do
    session = WhopMock.start
    session.store.insert("entry", entry_record(id: "entry_hooks_1", company_id: "biz_hooks_1", status: "pending"))
    session.store.insert("course_lesson_interaction",
                         course_lesson_interaction_record(id: "cli_hooks_1", company_id: "biz_hooks_1",
                                                          completed: true))
    session.store.insert("payout_account",
                         payout_account_record(id: "poacct_hooks_1").merge("company_id" => "biz_hooks_1"))
    session.store.insert("payout_method", payout_method_record(id: "pomethod_hooks_1", company_id: "biz_hooks_1"))
    session.store.insert("verification",
                         verification_record(id: "ver_hooks_1", company_id: "biz_hooks_1", status: "verified"))
    session.store.insert("payment", payment_record(id: "pay_resolution_hooks_1"))
    session.store.insert("resolution_center_case",
                         resolution_center_case_record(id: "rescase_hooks_1", company_id: "biz_hooks_1", payment_id: "pay_resolution_hooks_1",
                                                       status: "merchant_response_needed"))
    session.store.insert("dispute",
                         dispute_record(id: "disp_hooks_1", company_id: "biz_hooks_1", payment_id: "pay_dispute_hooks_1",
                                        status: "needs_response", editable: true))
    session.store.insert("dispute_alert",
                         dispute_alert_record(id: "dalert_hooks_1", dispute_id: "disp_hooks_1",
                                              payment_id: "pay_dispute_hooks_1"))
    session.store.insert("withdrawal",
                         withdrawal_record(id: "wd_hooks_1", company_id: "biz_hooks_1",
                                           created_at: "2026-04-29T10:00:00Z").merge("status" => "requested"))

    webhook_client = build_client(webhook_key: WhopMock.sign_webhook({},
                                                                     secret: "test_broader_hook_secret").fetch("secret"))
    unwrap = lambda do |event_type, data_id:, webhook_id:|
      event = WhopMock.mock_webhook_event(event_type, data: { id: data_id })
      signed = WhopMock.sign_webhook(event, secret: webhook_client.webhook_key, webhook_id: webhook_id,
                                            timestamp: Time.now.to_i)
      webhook_client.webhooks.unwrap(signed.fetch("payload"), headers: signed.fetch("headers"))
    end

    entry_created = unwrap.call("entry.created", data_id: "entry_hooks_1", webhook_id: "msg_entry_created")
    expect(entry_created).to be_a(WhopSDK::Models::EntryCreatedWebhookEvent)
    expect(entry_created.data.status).to eq(:pending)

    entry_approved = unwrap.call("entry.approved", data_id: "entry_hooks_1", webhook_id: "msg_entry_approved")
    expect(entry_approved).to be_a(WhopSDK::Models::EntryApprovedWebhookEvent)
    expect(entry_approved.data.status).to eq(:approved)

    entry_deleted = unwrap.call("entry.deleted", data_id: "entry_hooks_1", webhook_id: "msg_entry_deleted")
    expect(entry_deleted).to be_a(WhopSDK::Models::EntryDeletedWebhookEvent)
    expect(entry_deleted.data.status).to eq(:denied)

    entry_denied = unwrap.call("entry.denied", data_id: "entry_hooks_1", webhook_id: "msg_entry_denied")
    expect(entry_denied).to be_a(WhopSDK::Models::EntryDeniedWebhookEvent)
    expect(entry_denied.data.status).to eq(:denied)

    lesson_completed = unwrap.call("course_lesson_interaction.completed", data_id: "cli_hooks_1",
                                                                          webhook_id: "msg_lesson_completed")
    expect(lesson_completed).to be_a(WhopSDK::Models::CourseLessonInteractionCompletedWebhookEvent)
    expect(lesson_completed.data.completed).to eq(true)

    payout_account_updated = unwrap.call("payout_account.status_updated", data_id: "poacct_hooks_1",
                                                                          webhook_id: "msg_payout_account")
    expect(payout_account_updated).to be_a(WhopSDK::Models::PayoutAccountStatusUpdatedWebhookEvent)
    expect(payout_account_updated.data.status.to_s).to eq("active")

    payout_method_created = unwrap.call("payout_method.created", data_id: "pomethod_hooks_1",
                                                                 webhook_id: "msg_payout_method")
    expect(payout_method_created).to be_a(WhopSDK::Models::PayoutMethodCreatedWebhookEvent)
    expect(payout_method_created.data.id).to eq("pomethod_hooks_1")

    verification_succeeded = unwrap.call("verification.succeeded", data_id: "ver_hooks_1",
                                                                   webhook_id: "msg_verification")
    expect(verification_succeeded).to be_a(WhopSDK::Models::VerificationSucceededWebhookEvent)
    expect(verification_succeeded.data.status).to eq(:verified)

    resolution_created = unwrap.call("resolution_center_case.created", data_id: "rescase_hooks_1",
                                                                       webhook_id: "msg_resolution_created")
    expect(resolution_created).to be_a(WhopSDK::Models::ResolutionCenterCaseCreatedWebhookEvent)
    expect(resolution_created.data.status).to eq(:merchant_response_needed)

    resolution_updated = unwrap.call("resolution_center_case.updated", data_id: "rescase_hooks_1",
                                                                       webhook_id: "msg_resolution_updated")
    expect(resolution_updated).to be_a(WhopSDK::Models::ResolutionCenterCaseUpdatedWebhookEvent)
    expect(resolution_updated.data.status).to eq(:merchant_response_needed)

    resolution_decided = unwrap.call("resolution_center_case.decided", data_id: "rescase_hooks_1",
                                                                       webhook_id: "msg_resolution_decided")
    expect(resolution_decided).to be_a(WhopSDK::Models::ResolutionCenterCaseDecidedWebhookEvent)
    expect(resolution_decided.data.status).to eq(:merchant_won)

    dispute_created = unwrap.call("dispute.created", data_id: "disp_hooks_1", webhook_id: "msg_dispute_created")
    expect(dispute_created).to be_a(WhopSDK::Models::DisputeCreatedWebhookEvent)
    expect(dispute_created.data.status).to eq(:needs_response)

    dispute_updated = unwrap.call("dispute.updated", data_id: "disp_hooks_1", webhook_id: "msg_dispute_updated")
    expect(dispute_updated).to be_a(WhopSDK::Models::DisputeUpdatedWebhookEvent)
    expect(dispute_updated.data.status).to eq(:under_review)

    dispute_alert_created = unwrap.call("dispute_alert.created", data_id: "dalert_hooks_1",
                                                                 webhook_id: "msg_dispute_alert")
    expect(dispute_alert_created).to be_a(WhopSDK::Models::DisputeAlertCreatedWebhookEvent)
    expect(dispute_alert_created.data.alert_type).to eq(:dispute)

    withdrawal_created = unwrap.call("withdrawal.created", data_id: "wd_hooks_1", webhook_id: "msg_withdrawal_created")
    expect(withdrawal_created).to be_a(WhopSDK::Models::WithdrawalCreatedWebhookEvent)
    expect(withdrawal_created.data.status).to eq(:requested)

    withdrawal_updated = unwrap.call("withdrawal.updated", data_id: "wd_hooks_1", webhook_id: "msg_withdrawal_updated")
    expect(withdrawal_updated).to be_a(WhopSDK::Models::WithdrawalUpdatedWebhookEvent)
    expect(withdrawal_updated.data.status).to eq(:completed)
  end

  it "fabricates and unwraps create-heavy webhook sequences from payment and invoice variants" do
    session = WhopMock.start
    token = WhopMock.generate_payment_token(last4: "4242", exp_month: 5, exp_year: 2036, brand: "visa", country: "US")
    session.store.insert("company", company_record(id: "biz_create_hooks", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_create_hooks", company_id: "biz_create_hooks", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Create Hooks Product"
                                    ))
    session.store.insert("plan", plan_record(id: "plan_create_hooks", company_id: "biz_create_hooks", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_create_hooks",
                                   "product" => { "id" => "prod_create_hooks", "title" => "Create Hooks Product" },
                                   "currency" => "usd",
                                   "renewal_price" => 30.0,
                                   "title" => "Create Hooks Plan"
                                 ))
    session.store.insert("payment_method", payment_method_record(id: "pmt_method_create_hooks", created_at: "2026-04-29T10:00:00Z", last4: "4242").merge(
                                             "payment_method_type" => "card"
                                           ))

    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_create_hooks",
        member_id: "mb_create_hooks",
        payment_method_id: "pmt_method_create_hooks",
        plan_id: "plan_create_hooks",
        metadata: {
          campaign: "spring-hooks",
          nested: { cohort: "alpha" }
        }
      }
    )

    invoice = client.invoices.create(
      body: {
        collection_method: :charge_automatically,
        company_id: "biz_create_hooks",
        member_id: "mb_invoice_create_hooks",
        payment_token_id: token.fetch("id"),
        product_id: "prod_create_hooks",
        plan: {},
        due_date: "2026-05-12T10:00:00Z",
        save_as_draft: true
      }
    )

    payment_created_event = WhopMock.mock_webhook_event("payment.created", data: { id: payment.id })
    expect(payment_created_event.fetch("company_id")).to eq("biz_create_hooks")
    expect(payment_created_event.dig("data", "metadata", "campaign")).to eq("spring-hooks")
    expect(payment_created_event.dig("data", "payment_method", "last4")).to eq("4242")
    expect(payment_created_event.dig("data", "invoice", "id")).to eq(payment.to_h.fetch(:invoice_id))
    expect(payment_created_event.dig("data", "membership", "id")).to eq(payment.to_h.fetch(:membership_id))

    payment_succeeded_event = WhopMock.mock_webhook_event("payment.succeeded", data: { id: payment.id })
    expect(payment_succeeded_event.dig("data", "status")).to eq("paid")
    expect(payment_succeeded_event.dig("data", "substatus")).to eq("succeeded")

    invoice_created_event = WhopMock.mock_webhook_event("invoice.created", data: { id: invoice.id })
    expect(invoice_created_event.fetch("company_id")).to eq("biz_create_hooks")
    expect(invoice_created_event.dig("data", "due_date")).to eq("2026-05-12T10:00:00Z")
    expect(invoice_created_event.dig("data", "user", "id")).to eq("mb_invoice_create_hooks")
    expect(invoice_created_event.dig("data", "current_plan", "id")).to eq(invoice.current_plan.id)
    expect(invoice_created_event.dig("data", "status")).to eq("draft")

    webhook_client = build_client(webhook_key: WhopMock.sign_webhook({},
                                                                     secret: "test_create_variant_secret").fetch("secret"))

    signed_payment_created = WhopMock.sign_webhook(payment_created_event, secret: webhook_client.webhook_key,
                                                                          webhook_id: "msg_payment_created_variant", timestamp: Time.now.to_i)
    unwrapped_payment_created = webhook_client.webhooks.unwrap(signed_payment_created.fetch("payload"),
                                                               headers: signed_payment_created.fetch("headers"))
    expect(unwrapped_payment_created).to be_a(WhopSDK::Models::PaymentCreatedWebhookEvent)
    expect(unwrapped_payment_created.data.id).to eq(payment.id)

    signed_payment_succeeded = WhopMock.sign_webhook(payment_succeeded_event, secret: webhook_client.webhook_key,
                                                                              webhook_id: "msg_payment_succeeded_variant", timestamp: Time.now.to_i)
    unwrapped_payment_succeeded = webhook_client.webhooks.unwrap(signed_payment_succeeded.fetch("payload"),
                                                                 headers: signed_payment_succeeded.fetch("headers"))
    expect(unwrapped_payment_succeeded).to be_a(WhopSDK::Models::PaymentSucceededWebhookEvent)
    expect(unwrapped_payment_succeeded.data.id).to eq(payment.id)

    signed_invoice_created = WhopMock.sign_webhook(invoice_created_event, secret: webhook_client.webhook_key,
                                                                          webhook_id: "msg_invoice_created_variant", timestamp: Time.now.to_i)
    unwrapped_invoice_created = webhook_client.webhooks.unwrap(signed_invoice_created.fetch("payload"),
                                                               headers: signed_invoice_created.fetch("headers"))
    expect(unwrapped_invoice_created).to be_a(WhopSDK::Models::InvoiceCreatedWebhookEvent)
    expect(unwrapped_invoice_created.data.id).to eq(invoice.id)
  end

  it "retrieves and lists companies through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("company", company_record(id: "biz_sdk_2", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    company = client.companies.retrieve("biz_sdk_1")
    expect(company).to be_a(WhopSDK::Company)
    expect(company.to_h.fetch(:id)).to eq("biz_sdk_1")

    ids = []
    client.companies.list(first: 1).auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[biz_sdk_2 biz_sdk_1])
  end

  it "updates and filters companies through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_company_filter_1", created_at: "2026-04-29T10:00:00Z").merge(
                                      "parent_company_id" => "biz_parent"
                                    ))
    session.store.insert("company", company_record(id: "biz_company_filter_2", created_at: "2026-04-29T11:00:00Z").merge(
                                      "parent_company_id" => "biz_other_parent"
                                    ))

    client = build_client
    WhopMock.install!(client)

    updated = client.companies.update("biz_company_filter_1", title: "Updated Company Title")
    expect(updated.to_h.fetch(:title)).to eq("Updated Company Title")

    ids = []
    client.companies.list(parent_company_id: "biz_parent", direction: :asc, first: 10).auto_paging_each do |item|
      ids << item.to_h.fetch(:id)
    end
    expect(ids).to eq(%w[biz_company_filter_1])
  end

  it "retrieves and lists products through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("product",
                         product_record(id: "prod_sdk_1", company_id: "biz_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product",
                         product_record(id: "prod_sdk_2", company_id: "biz_sdk_1", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    product = client.products.retrieve("prod_sdk_1")
    expect(product).to be_a(WhopSDK::Product)
    expect(product.to_h.fetch(:id)).to eq("prod_sdk_1")

    ids = []
    client.products.list(company_id: "biz_sdk_1", first: 1).auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[prod_sdk_2 prod_sdk_1])
  end

  it "updates and filters products through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("product", product_record(id: "prod_filter_sdk_1", company_id: "biz_prod_filter", created_at: "2026-04-29T10:00:00Z").merge(
                                      "visibility" => "visible",
                                      "product_type" => "community",
                                      "member_count" => 5
                                    ))
    session.store.insert("product", product_record(id: "prod_filter_sdk_2", company_id: "biz_prod_filter", created_at: "2026-04-29T11:00:00Z").merge(
                                      "visibility" => "archived",
                                      "product_type" => "course",
                                      "member_count" => 1
                                    ))

    client = build_client
    WhopMock.install!(client)

    updated = client.products.update("prod_filter_sdk_1", title: "Updated Product Title")
    expect(updated.to_h.fetch(:title)).to eq("Updated Product Title")

    ids = []
    client.products.list(
      company_id: "biz_prod_filter",
      visibilities: [:visible],
      product_types: [:community],
      order: :active_memberships_count,
      direction: :desc,
      first: 10
    ).auto_paging_each { |item| ids << item.to_h.fetch(:id) }

    expect(ids).to eq(%w[prod_filter_sdk_1])
  end

  it "retrieves and lists plans through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("plan",
                         plan_record(id: "plan_sdk_1", company_id: "biz_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("plan",
                         plan_record(id: "plan_sdk_2", company_id: "biz_sdk_1", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    plan = client.plans.retrieve("plan_sdk_1")
    expect(plan).to be_a(WhopSDK::Plan)
    expect(plan.to_h.fetch(:id)).to eq("plan_sdk_1")

    ids = []
    client.plans.list(company_id: "biz_sdk_1", first: 1).auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[plan_sdk_2 plan_sdk_1])
  end

  it "updates and filters plans through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("plan", plan_record(id: "plan_filter_sdk_1", company_id: "biz_plan_filter", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_plan_filter",
                                   "plan_type" => "renewal",
                                   "release_method" => "buy_now",
                                   "visibility" => "visible",
                                   "member_count" => 8
                                 ))
    session.store.insert("plan", plan_record(id: "plan_filter_sdk_2", company_id: "biz_plan_filter", created_at: "2026-04-29T11:00:00Z").merge(
                                   "product_id" => "prod_other_filter",
                                   "plan_type" => "one_time",
                                   "release_method" => "hidden",
                                   "visibility" => "archived",
                                   "member_count" => 2
                                 ))

    client = build_client
    WhopMock.install!(client)

    updated = client.plans.update("plan_filter_sdk_1", title: "Updated Plan Title")
    expect(updated.to_h.fetch(:title)).to eq("Updated Plan Title")

    ids = []
    client.plans.list(
      company_id: "biz_plan_filter",
      product_ids: ["prod_plan_filter"],
      plan_types: [:renewal],
      release_methods: [:buy_now],
      visibilities: [:visible],
      order: :active_members_count,
      direction: :desc,
      first: 10
    ).auto_paging_each { |item| ids << item.to_h.fetch(:id) }

    expect(ids).to eq(%w[plan_filter_sdk_1])
  end

  it "creates retrieves lists and deletes promo codes through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_promo_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_promo_sdk", company_id: "biz_promo_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Promo Product"
                                    ))
    session.store.insert("plan", plan_record(id: "plan_promo_sdk", company_id: "biz_promo_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_promo_sdk",
                                   "product" => { "id" => "prod_promo_sdk", "title" => "Promo Product" },
                                   "title" => "Promo Plan"
                                 ))
    session.store.insert("promo_code", promo_code_record(
      id: "promo_existing_sdk",
      company_id: "biz_promo_sdk",
      product_id: "prod_promo_sdk",
      created_at: "2026-04-28T10:00:00Z",
      status: "inactive"
    ).merge(
      "code" => "ARCHIVE20",
      "plan_ids" => ["plan_promo_sdk"]
    ))

    client = build_client
    WhopMock.install!(client)

    created = client.promo_codes.create(
      amount_off: 15.0,
      base_currency: :usd,
      code: "WELCOME15",
      company_id: "biz_promo_sdk",
      new_users_only: true,
      promo_duration_months: 3,
      promo_type: :percentage,
      one_per_customer: true,
      product_id: "prod_promo_sdk",
      plan_ids: ["plan_promo_sdk"],
      stock: 50,
      unlimited_stock: false
    )

    expect(created).to be_a(WhopSDK::PromoCode)
    expect(created.company.id).to eq("biz_promo_sdk")
    expect(created.product.id).to eq("prod_promo_sdk")
    expect(created.currency).to eq(:usd)
    expect(created.status).to eq(:active)
    expect(created.code).to eq("WELCOME15")

    retrieved = client.promo_codes.retrieve(created.id)
    expect(retrieved.code).to eq("WELCOME15")
    expect(retrieved.promo_type).to eq(:percentage)

    listed_ids = []
    client.promo_codes.list(
      company_id: "biz_promo_sdk",
      product_ids: ["prod_promo_sdk"],
      plan_ids: ["plan_promo_sdk"],
      status: :inactive,
      first: 10
    ).auto_paging_each { |item| listed_ids << item.id }
    expect(listed_ids).to eq(["promo_existing_sdk"])

    active_ids = []
    client.promo_codes.list(
      company_id: "biz_promo_sdk",
      created_after: "2026-04-29T00:00:00Z",
      status: :active,
      first: 10
    ).auto_paging_each { |item| active_ids << item.id }
    expect(active_ids).to include(created.id)

    expect(client.promo_codes.delete(created.id)).to eq(true)
    expect { client.promo_codes.retrieve(created.id) }.to raise_error(WhopSDK::Errors::NotFoundError)
  end

  it "rejects invalid promo code list parameter combinations with real sdk errors" do
    client = build_client
    WhopMock.start
    WhopMock.install!(client)

    expect do
      client.promo_codes.list(status: :active, first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)

    expect do
      client.promo_codes.list(company_id: "biz_promo_sdk", status: "bogus", first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError, /invalid status: bogus/)
  end

  it "creates retrieves and lists checkout configurations through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_checkout_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_checkout_sdk", company_id: "biz_checkout_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Checkout Product"
                                    ))
    session.store.insert("plan", plan_record(id: "plan_checkout_sdk", company_id: "biz_checkout_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                   "product_id" => "prod_checkout_sdk",
                                   "product" => { "id" => "prod_checkout_sdk", "title" => "Checkout Product" },
                                   "title" => "Checkout Plan"
                                 ))
    session.store.insert("checkout_configuration", checkout_configuration_record(
                                                     id: "chk_existing_sdk",
                                                     company_id: "biz_checkout_sdk",
                                                     plan_id: "plan_checkout_sdk",
                                                     created_at: "2026-04-28T10:00:00Z"
                                                   ))

    client = build_client
    WhopMock.install!(client)

    created = client.checkout_configurations.create(
      body: {
        allow_promo_codes: true,
        company_id: "biz_checkout_sdk",
        metadata: { source: "spec" },
        plan_id: "plan_checkout_sdk",
        redirect_url: "https://example.test/after"
      }
    )

    expect(created).to be_a(WhopSDK::CheckoutConfiguration)
    expect(created.company_id).to eq("biz_checkout_sdk")
    expect(created.mode).to eq(:payment)
    expect(created.plan.id).to eq("plan_checkout_sdk")
    expect(created.allow_promo_codes).to eq(true)
    expect(created.metadata.fetch(:source)).to eq("spec")
    expect(created.purchase_url).to include("session=#{created.id}")

    retrieved = client.checkout_configurations.retrieve(created.id)
    expect(retrieved.id).to eq(created.id)
    expect(retrieved.redirect_url).to eq("https://example.test/after")

    ids = []
    client.checkout_configurations.list(
      company_id: "biz_checkout_sdk",
      plan_id: "plan_checkout_sdk",
      created_after: "2026-04-28T00:00:00Z",
      direction: :asc,
      first: 10
    ).auto_paging_each { |item| ids << item.id }
    expect(ids).to include("chk_existing_sdk", created.id)
  end

  it "supports inline-plan and setup checkout configuration modes through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_checkout_modes", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("product", product_record(id: "prod_checkout_modes", company_id: "biz_checkout_modes", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Inline Checkout Product"
                                    ))

    client = build_client
    WhopMock.install!(client)

    payment_mode = client.checkout_configurations.create(
      body: {
        allow_promo_codes: true,
        company_id: "biz_checkout_modes",
        mode: :payment,
        plan: {
          billing_period: 30,
          company_id: "biz_checkout_modes",
          currency: :usd,
          initial_price: 15.0,
          plan_type: :renewal,
          product_id: "prod_checkout_modes",
          release_method: :buy_now,
          renewal_price: 15.0,
          title: "Inline Checkout Plan",
          trial_period_days: 7,
          visibility: :visible
        },
        redirect_url: "https://example.test/payment"
      }
    )

    expect(payment_mode.mode).to eq(:payment)
    expect(payment_mode.plan).not_to be_nil
    expect(payment_mode.plan.currency).to eq(:usd)
    expect(payment_mode.plan.id).to match(/\Aplan_/)
    expect(payment_mode.purchase_url).to include("/checkout/#{payment_mode.plan.id}?session=")

    setup_mode = client.checkout_configurations.create(
      body: {
        allow_promo_codes: false,
        company_id: "biz_checkout_modes",
        mode: :setup,
        payment_method_configuration: {
          disabled: [],
          enabled: [:card],
          include_platform_defaults: true
        },
        redirect_url: "https://example.test/setup"
      }
    )

    expect(setup_mode.mode).to eq(:setup)
    expect(setup_mode.plan).to be_nil
    expect(setup_mode.company_id).to eq("biz_checkout_modes")
    expect(setup_mode.allow_promo_codes).to eq(false)
    expect(setup_mode.payment_method_configuration.enabled).to eq([:card])
    expect(setup_mode.purchase_url).to include("/checkout/setup?session=")
  end

  it "rejects invalid checkout configuration list parameter combinations with real sdk errors" do
    client = build_client
    WhopMock.start
    WhopMock.install!(client)

    expect do
      client.checkout_configurations.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)
  end

  it "retrieves and lists invoices through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("invoice",
                         invoice_record(id: "inv_sdk_1", company_id: "biz_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("invoice",
                         invoice_record(id: "inv_sdk_2", company_id: "biz_sdk_1", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    invoice = client.invoices.retrieve("inv_sdk_1")
    expect(invoice).to be_a(WhopSDK::Invoice)
    expect(invoice.to_h.fetch(:id)).to eq("inv_sdk_1")

    ids = []
    client.invoices.list(company_id: "biz_sdk_1", first: 1).auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[inv_sdk_2 inv_sdk_1])
  end

  it "applies invoice list filters and ordering through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("invoice", invoice_record(id: "inv_filter_1", company_id: "biz_invoice_filter", created_at: "2026-04-29T10:00:00Z").merge(
                                      "status" => "draft",
                                      "collection_method" => "send_invoice",
                                      "product_id" => "prod_invoice_filter",
                                      "due_date" => "2026-05-05T10:00:00Z"
                                    ))
    session.store.insert("invoice", invoice_record(id: "inv_filter_2", company_id: "biz_invoice_filter", created_at: "2026-04-29T11:00:00Z").merge(
                                      "status" => "paid",
                                      "collection_method" => "charge_automatically",
                                      "product_id" => "prod_invoice_filter",
                                      "due_date" => "2026-05-01T10:00:00Z"
                                    ))
    session.store.insert("invoice", invoice_record(id: "inv_filter_3", company_id: "biz_other_invoice", created_at: "2026-04-29T12:00:00Z").merge(
                                      "status" => "draft",
                                      "collection_method" => "send_invoice",
                                      "product_id" => "prod_other_invoice",
                                      "due_date" => "2026-05-03T10:00:00Z"
                                    ))

    client = build_client
    WhopMock.install!(client)

    ids = []
    client.invoices.list(
      company_id: "biz_invoice_filter",
      statuses: [:draft],
      collection_methods: [:send_invoice],
      product_ids: ["prod_invoice_filter"],
      direction: :asc,
      order: :due_date
    ).auto_paging_each { |item| ids << item.to_h.fetch(:id) }

    expect(ids).to eq(%w[inv_filter_1])
  end

  it "supports invoice action methods through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("invoice",
                         invoice_record(id: "inv_sdk_1", company_id: "biz_sdk_1", created_at: "2026-04-29T10:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    expect(client.invoices.mark_paid("inv_sdk_1")).to eq(true)
    expect(client.invoices.retrieve("inv_sdk_1").to_h.fetch(:status)).to eq(:paid)

    expect(client.invoices.mark_uncollectible("inv_sdk_1")).to eq(true)
    expect(client.invoices.retrieve("inv_sdk_1").to_h.fetch(:status)).to eq(:uncollectible)

    expect(client.invoices.void("inv_sdk_1")).to eq(true)
    expect(client.invoices.retrieve("inv_sdk_1").to_h.fetch(:status)).to eq(:void)

    expect(client.invoices.delete("inv_sdk_1")).to eq(true)
    expect { client.invoices.retrieve("inv_sdk_1") }.to raise_error(WhopSDK::Errors::NotFoundError)
  end

  it "retrieves and lists refunds through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("refund", refund_record(id: "ref_sdk_1", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("refund", refund_record(id: "ref_sdk_2", created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    refund = client.refunds.retrieve("ref_sdk_1")
    expect(refund.class.name).to include("RefundRetrieveResponse")
    expect(refund.to_h.fetch(:id)).to eq("ref_sdk_1")

    ids = []
    client.refunds.list(first: 1).auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[ref_sdk_2 ref_sdk_1])
  end

  it "applies refund list filters through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payment", payment_record(id: "pay_ref_filter_1", created_at: "2026-04-29T10:00:00Z").merge(
                                      "company_id" => "biz_ref_filter",
                                      "user" => { "id" => "usr_ref_filter_1", "email" => "one@example.com",
                                                  "name" => "One", "username" => "one" }
                                    ))
    session.store.insert("payment", payment_record(id: "pay_ref_filter_2", created_at: "2026-04-29T11:00:00Z").merge(
                                      "company_id" => "biz_other_ref_filter",
                                      "user" => { "id" => "usr_ref_filter_2", "email" => "two@example.com",
                                                  "name" => "Two", "username" => "two" }
                                    ))
    session.store.insert("refund", refund_record(id: "ref_filter_1", created_at: "2026-04-29T10:30:00Z").merge(
                                     "payment" => { "id" => "pay_ref_filter_1" }
                                   ))
    session.store.insert("refund", refund_record(id: "ref_filter_2", created_at: "2026-04-29T11:30:00Z").merge(
                                     "payment" => { "id" => "pay_ref_filter_2" }
                                   ))

    client = build_client
    WhopMock.install!(client)

    ids = []
    client.refunds.list(company_id: "biz_ref_filter", payment_id: "pay_ref_filter_1", user_id: "usr_ref_filter_1",
                        first: 10)
          .auto_paging_each do |item|
      ids << item.to_h.fetch(:id)
    end

    expect(ids).to eq(%w[ref_filter_1])
  end

  it "retrieves and lists setup intents through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("setup_intent",
                         setup_intent_record(id: "setup_sdk_1", company_id: "biz_sdk_1",
                                             created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("setup_intent",
                         setup_intent_record(id: "setup_sdk_2", company_id: "biz_sdk_1",
                                             created_at: "2026-04-29T11:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    setup_intent = client.setup_intents.retrieve("setup_sdk_1")
    expect(setup_intent).to be_a(WhopSDK::SetupIntent)
    expect(setup_intent.to_h.fetch(:id)).to eq("setup_sdk_1")

    ids = []
    client.setup_intents.list(company_id: "biz_sdk_1", first: 1).auto_paging_each { |item| ids << item.to_h.fetch(:id) }
    expect(ids).to eq(%w[setup_sdk_2 setup_sdk_1])
  end

  it "applies setup intent list filters through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("setup_intent",
                         setup_intent_record(id: "setup_filter_1", company_id: "biz_setup_filter",
                                             created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("setup_intent",
                         setup_intent_record(id: "setup_filter_2", company_id: "biz_setup_filter",
                                             created_at: "2026-04-29T11:00:00Z"))
    session.store.insert("setup_intent",
                         setup_intent_record(id: "setup_filter_3", company_id: "biz_other_setup_filter",
                                             created_at: "2026-04-29T12:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    ids = []
    client.setup_intents.list(
      company_id: "biz_setup_filter",
      created_after: Time.parse("2026-04-29T10:30:00Z"),
      direction: :asc,
      first: 10
    ).auto_paging_each { |item| ids << item.to_h.fetch(:id) }

    expect(ids).to eq(%w[setup_filter_2])
  end

  it "supports delete methods for plans and products through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("plan", plan_record(id: "plan_sdk_1", company_id: "biz_sdk_1"))
    session.store.insert("product", product_record(id: "prod_sdk_1", company_id: "biz_sdk_1"))

    client = build_client
    WhopMock.install!(client)

    expect(client.plans.delete("plan_sdk_1")).to eq(true)
    expect { client.plans.retrieve("plan_sdk_1") }.to raise_error(WhopSDK::Errors::NotFoundError)

    expect(client.products.delete("prod_sdk_1")).to eq(true)
    expect { client.products.retrieve("prod_sdk_1") }.to raise_error(WhopSDK::Errors::NotFoundError)
  end

  it "supports webhook CRUD and list flows through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_hook_1"))

    client = build_client
    WhopMock.install!(client)

    created = client.webhooks.create(
      url: "https://example.com/hooks/primary",
      resource_id: "biz_hook_1",
      events: %i[payment.succeeded invoice.paid],
      enabled: true,
      child_resource_events: false
    )
    expect(created.to_h.fetch(:id)).to start_with("whk_")
    expect(created.to_h.fetch(:webhook_secret).to_s).to start_with("ws_")

    retrieved = client.webhooks.retrieve(created.id)
    expect(retrieved.to_h.fetch(:resource_id)).to eq("biz_hook_1")

    listed_ids = []
    client.webhooks.list(company_id: "biz_hook_1", first: 10).auto_paging_each do |item|
      listed_ids << item.to_h.fetch(:id)
    end
    expect(listed_ids).to include(created.id)

    updated = client.webhooks.update(created.id, enabled: false, url: "https://example.com/hooks/secondary")
    expect(updated.to_h.fetch(:enabled)).to eq(false)
    expect(updated.to_h.fetch(:url)).to eq("https://example.com/hooks/secondary")

    expect(client.webhooks.delete(created.id)).to eq(true)
    expect { client.webhooks.retrieve(created.id) }.to raise_error(WhopSDK::Errors::NotFoundError)
  end

  it "retrieves and lists members through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("member",
                         member_record(id: "mb_sdk_1", company_id: "biz_member_sdk",
                                       created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("member", member_record(id: "mb_sdk_2", company_id: "biz_member_sdk", created_at: "2026-04-29T11:00:00Z").merge(
                                     "most_recent_action" => "left",
                                     "most_recent_action_at" => "2026-04-29T11:30:00Z",
                                     "status" => "left",
                                     "user" => {
                                       "id" => "usr_mb_sdk_2",
                                       "email" => "beta@example.com",
                                       "name" => "Beta Member",
                                       "username" => "beta-member"
                                     }
                                   ))

    client = build_client
    WhopMock.install!(client)

    member = client.members.retrieve("mb_sdk_1")
    expect(member.id).to eq("mb_sdk_1")
    expect(member.user.email).to eq("mb_sdk_1@example.com")
    expect(member.user.username).to eq("mb_sdk_1")
    expect(member.company.title).to eq("Member Co")

    ids = []
    client.members.list(
      company_id: "biz_member_sdk",
      statuses: [:joined],
      most_recent_actions: [:joined],
      query: "mb_sdk_1@example.com",
      order: :most_recent_action,
      direction: :desc,
      first: 10
    )
          .auto_paging_each { |item| ids << item.id }
    expect(ids).to eq(["mb_sdk_1"])
  end

  it "retrieves payout accounts and lists payout methods through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("payout_account", payout_account_record(id: "poacct_sdk_1", company_id: "biz_payout_sdk"))
    session.store.insert("payout_method",
                         payout_method_record(id: "pomethod_sdk_1", company_id: "biz_payout_sdk",
                                              created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("payout_method", payout_method_record(id: "pomethod_sdk_2", company_id: "biz_payout_sdk", created_at: "2026-04-29T11:00:00Z").merge(
                                            "last4" => "4321"
                                          ))

    client = build_client
    WhopMock.install!(client)

    payout_account = client.payout_accounts.retrieve("poacct_sdk_1")
    expect(payout_account.id).to eq("poacct_sdk_1")
    expect(payout_account.business_representative.first_name).to eq("Avery")
    expect(payout_account.email).to eq("owner@acme.test")

    payout_method = client.payout_methods.retrieve("pomethod_sdk_1")
    expect(payout_method.id).to eq("pomethod_sdk_1")
    expect(payout_method.destination.name).to eq("Avery Owner")
    expect(payout_method.account_reference).to eq("••••6789")

    ids = []
    client.payout_methods.list(company_id: "biz_payout_sdk", first: 10).auto_paging_each { |item| ids << item.id }
    expect(ids).to eq(%w[pomethod_sdk_2 pomethod_sdk_1])
  end

  it "retrieves ledger accounts through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("ledger_account",
                         ledger_account_record(id: "ledger_biz_sdk", owner_type: "Company", owner_id: "biz_ledger_sdk"))
    session.store.insert("ledger_account",
                         ledger_account_record(id: "ledger_user_sdk", owner_type: "User", owner_id: "usr_ledger_sdk"))

    client = build_client
    WhopMock.install!(client)

    company_ledger = client.ledger_accounts.retrieve("ledger_biz_sdk")
    expect(company_ledger.id).to eq("ledger_biz_sdk")
    expect(company_ledger.ledger_type).to eq(:primary)
    expect(company_ledger.owner.typename).to eq(:Company)
    expect(company_ledger.owner.id).to eq("biz_ledger_sdk")
    expect(company_ledger.balances.first.balance).to eq(125.5)
    expect(company_ledger.balances.first.pending_balance).to eq(10.0)
    expect(company_ledger.payout_account_details.business_name).to eq("Acme LLC")
    expect(company_ledger.payments_approval_status).to eq(:approved)

    user_ledger = client.ledger_accounts.retrieve("ledger_user_sdk")
    expect(user_ledger.owner.typename).to eq(:User)
    expect(user_ledger.owner.username).to eq("ledger-user")
  end

  it "creates account links through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_account_link_sdk", created_at: "2026-04-29T10:00:00Z").merge(
                                      "title" => "Account Link Co"
                                    ))

    client = build_client
    WhopMock.install!(client)

    created = client.account_links.create(
      company_id: "biz_account_link_sdk",
      refresh_url: "https://example.test/refresh",
      return_url: "https://example.test/return",
      use_case: :account_onboarding
    )

    expect(created).to be_a(WhopSDK::Models::AccountLinkCreateResponse)
    expect(created.url).to include("/companies/biz_account_link_sdk/account_links/account_onboarding")
    expect(created.url).to include("session=")
    expect(created.expires_at).to be_a(Time)
  end

  it "rejects invalid account link payloads with real sdk errors" do
    client = build_client
    WhopMock.start
    WhopMock.install!(client)

    expect do
      client.account_links.create(
        refresh_url: "https://example.test/refresh",
        return_url: "https://example.test/return",
        use_case: :account_onboarding
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)

    expect do
      client.account_links.create(
        company_id: "biz_account_link_sdk",
        refresh_url: "https://example.test/refresh",
        return_url: "https://example.test/return",
        use_case: "bogus"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /invalid account_link\.use_case: bogus/)
  end

  it "creates lists updates and deletes fee markups through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_fee_markup_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("fee_markup", fee_markup_record(
                                         id: "feemarkup_seed_sdk",
                                         company_id: "biz_fee_markup_sdk",
                                         fee_type: "crypto_withdrawal_markup",
                                         created_at: "2026-04-29T10:00:00Z"
                                       ))

    client = build_client
    WhopMock.install!(client)

    created = client.fee_markups.create(
      company_id: "biz_fee_markup_sdk",
      fee_type: :digital_wallet_withdrawal_markup,
      fixed_fee_usd: 2.0,
      percentage_fee: 1.5,
      notes: "Digital wallet fee"
    )

    expect(created.id).to match(/\Afeemarkup_/)
    expect(created.fee_type).to eq(:digital_wallet_withdrawal_markup)
    expect(created.fixed_fee_usd).to eq(2.0)
    expect(created.percentage_fee).to eq(1.5)

    upserted = client.fee_markups.create(
      company_id: "biz_fee_markup_sdk",
      fee_type: :digital_wallet_withdrawal_markup,
      fixed_fee_usd: 3.5,
      percentage_fee: 2.25,
      notes: "Updated digital wallet fee"
    )

    expect(upserted.id).to eq(created.id)
    expect(upserted.fixed_fee_usd).to eq(3.5)
    expect(upserted.percentage_fee).to eq(2.25)
    expect(upserted.notes).to eq("Updated digital wallet fee")

    ids = []
    client.fee_markups.list(company_id: "biz_fee_markup_sdk", first: 10).auto_paging_each { |item| ids << item.id }
    expect(ids).to include("feemarkup_seed_sdk", created.id)
    expect(ids.count(created.id)).to eq(1)

    expect(client.fee_markups.delete(created.id)).to eq(true)
  end

  it "rejects invalid fee markup payloads and list params with real sdk errors" do
    client = build_client
    WhopMock.start
    WhopMock.install!(client)

    expect do
      client.fee_markups.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)

    expect do
      client.fee_markups.create(
        company_id: "biz_fee_markup_sdk",
        fee_type: "bogus",
        fixed_fee_usd: 2.0
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /invalid fee_markup\.fee_type: bogus/)

    expect do
      client.fee_markups.create(
        company_id: "biz_fee_markup_sdk",
        fee_type: :digital_wallet_withdrawal_markup,
        fixed_fee_usd: 75.0
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /fixed_fee_usd must be between 0 and 50/)
  end

  it "creates topups through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("company", company_record(id: "biz_topup_sdk", created_at: "2026-04-29T10:00:00Z"))
    session.store.insert("payment_method", payment_method_record(id: "pmt_method_topup_sdk").merge(
                                             "created_at" => "2026-04-29T10:00:00Z"
                                           ))

    client = build_client
    WhopMock.install!(client)

    created = client.topups.create(
      amount: 50.0,
      company_id: "biz_topup_sdk",
      currency: :usd,
      payment_method_id: "pmt_method_topup_sdk"
    )

    expect(created.id).to match(/\Atopup_/)
    expect(created.currency).to eq(:usd)
    expect(created.status).to eq(:paid)
    expect(created.total).to eq(50.0)
    expect(created.paid_at).to be_a(Time)
  end

  it "rejects invalid topup payloads with real sdk errors" do
    client = build_client
    WhopMock.start
    WhopMock.install!(client)

    expect do
      client.topups.create(
        amount: 50.0,
        currency: :usd,
        payment_method_id: "pmt_method_topup_sdk"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)

    expect do
      client.topups.create(
        amount: 0.0,
        company_id: "biz_topup_sdk",
        currency: :usd,
        payment_method_id: "pmt_method_topup_sdk"
      )
    end.to raise_error(WhopSDK::Errors::BadRequestError, /amount must be greater than 0/)
  end

  it "retrieves lists and updates disputes through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("dispute", dispute_record(
                                      id: "disp_sdk_1",
                                      company_id: "biz_dispute_sdk",
                                      payment_id: "pay_dispute_sdk",
                                      plan_id: "plan_dispute_sdk",
                                      product_id: "prod_dispute_sdk",
                                      created_at: "2026-04-29T10:00:00Z"
                                    ))
    session.store.insert("dispute", dispute_record(
                                      id: "disp_sdk_2",
                                      company_id: "biz_dispute_sdk",
                                      payment_id: "pay_dispute_sdk_2",
                                      plan_id: "plan_dispute_sdk",
                                      product_id: "prod_dispute_sdk",
                                      created_at: "2026-04-29T11:00:00Z",
                                      status: "closed",
                                      editable: false
                                    ))

    client = build_client
    WhopMock.install!(client)

    dispute = client.disputes.retrieve("disp_sdk_1")
    expect(dispute.id).to eq("disp_sdk_1")
    expect(dispute.status).to eq(:needs_response)
    expect(dispute.payment.id).to eq("pay_dispute_sdk")

    ids = []
    client.disputes.list(
      company_id: "biz_dispute_sdk",
      created_after: "2026-04-29T09:30:00Z",
      direction: :asc,
      first: 10
    ).auto_paging_each { |item| ids << item.id }
    expect(ids).to eq(%w[disp_sdk_1 disp_sdk_2])

    updated = client.disputes.update_evidence(
      "disp_sdk_1",
      notes: "Buyer accessed the product successfully",
      customer_email_address: "buyer+updated@example.com"
    )
    expect(updated.notes).to eq("Buyer accessed the product successfully")
    expect(updated.customer_email_address).to eq("buyer+updated@example.com")

    submitted = client.disputes.submit_evidence("disp_sdk_1")
    expect(submitted.status).to eq(:under_review)
    expect(submitted.editable).to eq(false)
  end

  it "rejects invalid dispute list and action flows with real sdk errors" do
    session = WhopMock.start
    session.store.insert("dispute", dispute_record(
                                      id: "disp_invalid_sdk",
                                      company_id: "biz_dispute_sdk",
                                      editable: false,
                                      status: "closed"
                                    ))

    client = build_client
    WhopMock.install!(client)

    expect do
      client.disputes.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)

    expect do
      client.disputes.submit_evidence("disp_invalid_sdk")
    end.to raise_error(WhopSDK::Errors::UnprocessableEntityError, /cannot submit_evidence dispute in closed state/)
  end

  it "retrieves and lists dispute alerts through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("dispute_alert", dispute_alert_record(
      id: "dalert_sdk_1",
      dispute_id: "disp_sdk_1",
      payment_id: "pay_dispute_sdk",
      created_at: "2026-04-29T10:00:00Z"
    ).merge("company_id" => "biz_dispute_sdk"))
    session.store.insert("dispute_alert", dispute_alert_record(
      id: "dalert_sdk_2",
      dispute_id: "disp_sdk_2",
      payment_id: "pay_dispute_sdk_2",
      created_at: "2026-04-29T11:00:00Z",
      alert_type: "fraud"
    ).merge("company_id" => "biz_dispute_sdk"))

    client = build_client
    WhopMock.install!(client)

    alert = client.dispute_alerts.retrieve("dalert_sdk_1")
    expect(alert.id).to eq("dalert_sdk_1")
    expect(alert.alert_type).to eq(:dispute)
    expect(alert.payment.user.email).to eq("alert-user@example.com")
    expect(alert.dispute.status).to eq(:needs_response)

    ids = []
    client.dispute_alerts.list(
      company_id: "biz_dispute_sdk",
      created_after: "2026-04-29T09:00:00Z",
      direction: :asc,
      first: 10
    ).auto_paging_each { |item| ids << item.id }
    expect(ids).to eq(%w[dalert_sdk_1 dalert_sdk_2])
  end

  it "rejects invalid dispute alert list params with real sdk errors" do
    client = build_client
    WhopMock.start
    WhopMock.install!(client)

    expect do
      client.dispute_alerts.list(first: 10)
    end.to raise_error(WhopSDK::Errors::BadRequestError, /missing required fields: company_id/)
  end

  it "creates retrieves and lists transfers through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("transfer", transfer_record(id: "tr_sdk_seed", company_id: "biz_transfer_sdk", created_at: "2026-04-29T09:00:00Z").merge(
                                       "origin_id" => "biz_transfer_sdk",
                                       "destination_id" => "user_transfer_seed"
                                     ))

    client = build_client
    WhopMock.install!(client)

    created = client.transfers.create(
      amount: 55.0,
      currency: :usd,
      destination_id: "user_transfer_created",
      origin_id: "biz_transfer_sdk",
      metadata: { batch: "sdk-transfer" },
      notes: "creator payout"
    )
    expect(created.to_h.fetch(:amount)).to eq(55.0)
    expect(created.to_h.fetch(:origin_id)).to eq("biz_transfer_sdk")
    expect(created.to_h.fetch(:destination_id)).to eq("user_transfer_created")
    expect(created.origin.typename).to eq(:Company)
    expect(created.destination.typename).to eq(:User)
    expect(created.destination.username).to eq("user_transfer_created")

    retrieved = client.transfers.retrieve(created.id)
    expect(retrieved.to_h.fetch(:destination_id)).to eq("user_transfer_created")
    expect(retrieved.destination.username).to eq("user_transfer_created")

    ids = []
    client.transfers.list(origin_id: "biz_transfer_sdk", destination_id: "user_transfer_created", order: :amount,
                          direction: :desc, first: 10)
          .auto_paging_each do |item|
      ids << item.id
    end
    expect(ids).to eq([created.id])
  end

  it "creates retrieves and lists withdrawals through a real WhopSDK::Client" do
    session = WhopMock.start
    session.store.insert("withdrawal",
                         withdrawal_record(id: "wd_sdk_seed", company_id: "biz_withdrawal_sdk",
                                           created_at: "2026-04-29T09:00:00Z"))

    client = build_client
    WhopMock.install!(client)

    created = client.withdrawals.create(
      amount: 30.0,
      company_id: "biz_withdrawal_sdk",
      currency: :usd,
      payout_method_id: "pomethod_withdrawal_sdk",
      statement_descriptor: "PAYOUT"
    )
    expect(created.to_h.fetch(:amount)).to eq(30.0)
    expect(created.to_h.fetch(:company_id)).to eq("biz_withdrawal_sdk")
    expect(created.to_h.fetch(:payout_method_id)).to eq("pomethod_withdrawal_sdk")
    expect(created.payout_token.payer_name).to eq("Example")

    retrieved = client.withdrawals.retrieve(created.id)
    expect(retrieved.to_h.fetch(:payout_method_id)).to eq("pomethod_withdrawal_sdk")
    expect(retrieved.ledger_account.company_id).to eq("biz_withdrawal_sdk")

    ids = []
    client.withdrawals.list(company_id: "biz_withdrawal_sdk", first: 10).auto_paging_each { |item| ids << item.id }
    expect(ids).to include("wd_sdk_seed", created.id)
  end

  it "creates account links through the real sdk surface" do
    # Uses synced spec since account_links may not be in fixture
    WhopMock.reset_configuration!
    WhopMock.configure { |c| c.spec_path = nil }
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    result = client.account_links.create(
      company_id: "biz_test123",
      refresh_url: "https://example.com/refresh",
      return_url: "https://example.com/return",
      use_case: :payouts_portal
    )

    expect(result.url).to be_a(String)
    expect(result.expires_at).to be_a(Time)
  end

  it "unwraps signed webhook payloads through the real sdk webhook surface" do
    WhopMock.start
    client = build_client
    WhopMock.install!(client)

    payment = client.payments.create(
      body: {
        company_id: "biz_unwrap",
        member_id: "mb_unwrap",
        payment_method_id: "pmt_method_unwrap",
        plan: {
          currency: :usd,
          title: "Unwrap Plan",
          renewal_price: 10.0,
          product: { title: "Unwrap Product" }
        }
      }
    )

    event = WhopMock.mock_webhook_event("payment.succeeded", data: { id: payment.id })
    signed = WhopMock.sign_webhook(event, secret: "test_webhook_secret", webhook_id: "msg_unwrap",
                                          timestamp: Time.now.to_i)

    webhook_client = build_client(webhook_key: signed.fetch("secret"))
    unwrapped = webhook_client.webhooks.unwrap(signed.fetch("payload"), headers: signed.fetch("headers"))

    expect(unwrapped).to be_a(WhopSDK::Models::PaymentSucceededWebhookEvent)
    expect(unwrapped.to_h.fetch(:type).to_s).to eq("payment.succeeded")
    expect(unwrapped.data.id).to eq(payment.id)
  end
end
