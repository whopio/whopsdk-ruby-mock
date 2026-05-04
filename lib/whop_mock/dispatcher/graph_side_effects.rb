# frozen_string_literal: true

require "base64"
require "securerandom"

module WhopMock
  class Dispatcher
    module GraphSideEffects
      include ResourceNames

      private

      def apply_transient_side_effects(resource_name, record, payload)
        case ResourceNames.normalize(resource_name)
        when ACCOUNT_LINK
          build_transient_account_link(record, payload)
        else
          record
        end
      end

      def build_transient_account_link(record, payload)
        company_id = record["company_id"] || payload["company_id"]
        ensure_company_exists(company_id, record["company"] || payload["company"])
        use_case = (record["use_case"] || payload["use_case"] || "account_onboarding").to_s
        expires_at = record["expires_at"] || payload["expires_at"] || (Time.now.utc + (30 * 60)).iso8601

        record.merge(
          "company_id" => company_id,
          "expires_at" => expires_at,
          "refresh_url" => record["refresh_url"] || payload["refresh_url"],
          "return_url" => record["return_url"] || payload["return_url"],
          "url" => preferred_runtime_value(record["url"],
                                           account_link_url(record["id"], company_id: company_id, use_case: use_case)),
          "use_case" => use_case
        )
      end

      def apply_create_side_effects(resource_name, record, payload)
        case ResourceNames.normalize(resource_name)
        when ACCOUNT_LINK
          account_link = ensure_account_link_graph(record, payload)
          @store.find(resource_name, account_link["id"]) || account_link
        when FEE_MARKUP
          fee_markup = ensure_fee_markup_graph(record, payload)
          @store.find(resource_name, fee_markup["id"]) || fee_markup
        when TOPUP
          topup = ensure_topup_graph(record, payload)
          @store.find(resource_name, topup["id"]) || topup
        when CHECKOUT_CONFIGURATION
          checkout_configuration = ensure_checkout_configuration_graph(record, payload)
          @store.find(resource_name, checkout_configuration["id"]) || checkout_configuration
        when PRODUCT
          ensure_company_exists(company_id_for(record), record["company"])
          @store.find(resource_name, record["id"]) || record
        when PLAN
          ensure_company_exists(company_id_for(record), record["company"])
          ensure_product_exists(product_id_for(record), company_id_for(record), record["product"])
          @store.find(resource_name, record["id"]) || record
        when PROMO_CODE
          promo_code = ensure_promo_code_graph(record, payload)
          @store.find(resource_name, promo_code["id"]) || promo_code
        when INVOICE
          invoice = ensure_invoice_graph(record, payload)
          @store.find(resource_name, invoice["id"]) || invoice
        when PAYMENT
          payment = ensure_payment_graph(record, payload)
          @store.find(resource_name, payment["id"]) || payment
        when TRANSFER
          transfer = ensure_transfer_graph(record, payload)
          @store.find(resource_name, transfer["id"]) || transfer
        when WEBHOOK
          webhook = ensure_webhook_defaults(record, payload)
          @store.find(resource_name, webhook["id"]) || webhook
        when WITHDRAWAL
          withdrawal = ensure_withdrawal_graph(record, payload)
          @store.find(resource_name, withdrawal["id"]) || withdrawal
        else
          record
        end
      end

      def apply_action_side_effects(resource_name, action, previous, updated, attributes)
        case [ResourceNames.normalize(resource_name), action.to_s]
        when [PAYMENT, "refund"]
          apply_payment_refund_side_effect(previous, updated, attributes)
        when [PAYMENT, "retry"]
          sync_invoice_status(updated, "open")
          activate_membership_for(updated)
          @store.find(resource_name.to_s, updated["id"]) || updated
        when [PAYMENT, "void"]
          sync_invoice_status(updated, "void")
          cancel_membership_for(updated)
          @store.find(resource_name.to_s, updated["id"]) || updated
        when [INVOICE, "mark_paid"]
          sync_payment_status(updated, "paid", "succeeded")
          activate_membership_for(updated)
          @store.find(resource_name.to_s, updated["id"]) || updated
        when [INVOICE, "mark_uncollectible"]
          sync_payment_status(updated, "open", "failed")
          pause_membership_for(updated)
          @store.find(resource_name.to_s, updated["id"]) || updated
        when [INVOICE, "void"]
          sync_payment_status(updated, "void", "canceled")
          cancel_membership_for(updated)
          @store.find(resource_name.to_s, updated["id"]) || updated
        else
          updated
        end
      end

      def apply_update_side_effects(resource_name, previous, updated, attributes)
        case ResourceNames.normalize(resource_name)
        when INVOICE
          apply_invoice_update_side_effects(previous, updated, attributes)
        else
          updated
        end
      end

      def ensure_webhook_defaults(record, payload)
        events = Array(record["events"] || payload["events"]).map(&:to_s)
        defaults = {
          "api_version" => record["api_version"] || "v1",
          "child_resource_events" => record.key?("child_resource_events") ? record["child_resource_events"] : false,
          "enabled" => record.key?("enabled") ? record["enabled"] : true,
          "resource_id" => record["resource_id"] || payload["resource_id"] || payload["company_id"],
          "testable_events" => record["testable_events"] || events,
          "webhook_secret" => record["webhook_secret"] || "ws_#{SecureRandom.hex(32)}"
        }

        @store.update(WEBHOOK, record["id"], defaults)
        @store.find(WEBHOOK, record["id"]) || record
      end

      def generated_secret(current_value, fallback)
        return fallback if current_value.nil? || current_value.to_s.end_with?("_example")

        current_value
      end

      def preferred_runtime_value(current_value, fallback)
        return fallback if placeholder_value?(current_value)

        current_value
      end

      def placeholder_value?(value)
        return true if value.nil?

        str = value.to_s
        str.end_with?("_example") || str.start_with?("https://example.com/")
      end

      def ensure_promo_code_graph(record, payload)
        company_id = record["company_id"] || payload["company_id"]
        company = ensure_company_exists(company_id, record["company"] || payload["company"])
        product_id = record["product_id"] || payload["product_id"]
        product = ensure_product_exists(product_id, company_id, record["product"] || payload["product"])
        timestamps = default_timestamps(record["created_at"])

        duration =
          record["duration"] ||
          payload["duration"] ||
          case begin
            Integer(payload["promo_duration_months"] || record["promo_duration_months"] || 0)
          rescue StandardError
            0
          end
          when 0 then "once"
          when 1.. then "repeating"
          end

        status =
          record["status"] ||
          payload["status"] ||
          if payload.key?("archived_at") || record.key?("archived_at")
            "archived"
          else
            "active"
          end

        unlimited_stock =
          if payload.key?("unlimited_stock")
            payload["unlimited_stock"]
          elsif record.key?("unlimited_stock")
            record["unlimited_stock"]
          else
            record["stock"].nil? && payload["stock"].nil?
          end

        defaults = {
          "amount_off" => record["amount_off"] || payload["amount_off"],
          "churned_users_only" => boolean_value(record, payload, "churned_users_only", false),
          "code" => record["code"] || payload["code"],
          "company_id" => company_id,
          "company" => compact_company(company),
          "created_at" => timestamps["created_at"],
          "currency" => record["currency"] || payload["base_currency"] || payload["currency"] || "usd",
          "duration" => duration,
          "existing_memberships_only" => boolean_value(record, payload, "existing_memberships_only", false),
          "expires_at" => record["expires_at"] || payload["expires_at"],
          "new_users_only" => boolean_value(record, payload, "new_users_only", false),
          "one_per_customer" => boolean_value(record, payload, "one_per_customer", false),
          "plan_ids" => record["plan_ids"] || payload["plan_ids"] || [],
          "product_id" => product_id,
          "product" => compact_product(product),
          "promo_duration_months" => record["promo_duration_months"] || payload["promo_duration_months"],
          "promo_type" => record["promo_type"] || payload["promo_type"] || "percentage",
          "status" => status,
          "stock" => record["stock"] || payload["stock"] || 0,
          "unlimited_stock" => unlimited_stock,
          "updated_at" => timestamps["updated_at"],
          "uses" => record["uses"] || payload["uses"] || 0
        }

        @store.update(PROMO_CODE, record["id"], defaults)
        @store.find(PROMO_CODE, record["id"]) || record
      end

      def ensure_checkout_configuration_graph(record, payload)
        mode = (record["mode"] || payload["mode"] || (payload["plan_id"] || payload["plan"] ? "payment" : "setup")).to_s
        timestamps = default_timestamps(record["created_at"])
        payment_method_configuration = record["payment_method_configuration"] || payload["payment_method_configuration"]

        if mode == "setup"
          company_id = record["company_id"] || payload["company_id"]
          defaults = {
            "affiliate_code" => record["affiliate_code"] || payload["affiliate_code"],
            "allow_promo_codes" => boolean_value(record, payload, "allow_promo_codes", true),
            "company_id" => company_id,
            "created_at" => timestamps["created_at"],
            "currency" => record["currency"] || payload["currency"],
            "metadata" => record["metadata"] || payload["metadata"] || {},
            "mode" => "setup",
            "payment_method_configuration" => payment_method_configuration,
            "plan" => nil,
            "plan_id" => nil,
            "purchase_url" => preferred_runtime_value(record["purchase_url"], checkout_purchase_url(record["id"])),
            "redirect_url" => record["redirect_url"] || payload["redirect_url"]
          }
          @store.update(CHECKOUT_CONFIGURATION, record["id"], defaults)
          return @store.find(CHECKOUT_CONFIGURATION, record["id"]) || record
        end

        plan_payload = payload["plan"] || {}
        plan_id = payload["plan_id"] || record["plan_id"] || plan_payload["id"]
        existing_plan = @store.find(PLAN, plan_id) if plan_id
        company_id = record["company_id"] || payload["company_id"] || plan_payload["company_id"] || existing_plan&.fetch(
          "company_id", nil
        )
        product_payload = plan_payload["product"] || {}
        product_id = payload["product_id"] || plan_payload["product_id"] || product_payload["id"] || existing_plan&.fetch(
          "product_id", nil
        )
        product = ensure_product_exists(product_id, company_id, product_payload)
        plan = ensure_plan_exists(
          plan_id,
          company_id: company_id,
          product_id: product&.fetch("id", nil),
          source: plan_payload
        )

        defaults = compact_hash(
          "affiliate_code" => record["affiliate_code"] || payload["affiliate_code"],
          "allow_promo_codes" => boolean_value(record, payload, "allow_promo_codes", true),
          "company_id" => company_id,
          "created_at" => timestamps["created_at"],
          "currency" => record["currency"] || payload["currency"] || plan&.fetch("currency", nil),
          "metadata" => record["metadata"] || payload["metadata"] || {},
          "mode" => "payment",
          "payment_method_configuration" => payment_method_configuration || plan&.fetch("payment_method_configuration",
                                                                                        nil),
          "plan_id" => plan&.fetch("id", nil),
          "plan" => plan,
          "purchase_url" => preferred_runtime_value(record["purchase_url"],
                                                    checkout_purchase_url(record["id"],
                                                                          plan_id: plan&.fetch("id", nil))),
          "redirect_url" => record["redirect_url"] || payload["redirect_url"]
        )
        @store.update(CHECKOUT_CONFIGURATION, record["id"], defaults)
        @store.find(CHECKOUT_CONFIGURATION, record["id"]) || record
      end

      def ensure_account_link_graph(record, payload)
        company_id = record["company_id"] || payload["company_id"]
        ensure_company_exists(company_id, record["company"] || payload["company"])
        use_case = (record["use_case"] || payload["use_case"] || "account_onboarding").to_s
        expires_at = record["expires_at"] || payload["expires_at"] || (Time.now.utc + (30 * 60)).iso8601

        defaults = {
          "company_id" => company_id,
          "expires_at" => expires_at,
          "refresh_url" => record["refresh_url"] || payload["refresh_url"],
          "return_url" => record["return_url"] || payload["return_url"],
          "url" => preferred_runtime_value(record["url"],
                                           account_link_url(record["id"], company_id: company_id, use_case: use_case)),
          "use_case" => use_case
        }
        @store.update(ACCOUNT_LINK, record["id"], defaults)
        @store.find(ACCOUNT_LINK, record["id"]) || record
      end

      def ensure_fee_markup_graph(record, payload)
        company_id = record["company_id"] || payload["company_id"]
        ensure_company_exists(company_id, record["company"] || payload["company"])
        fee_type = (record["fee_type"] || payload["fee_type"]).to_s
        timestamps = default_timestamps(record["created_at"])

        existing = @store.list(FEE_MARKUP, company_id: company_id).find do |item|
          item["fee_type"].to_s == fee_type && item["id"] != record["id"]
        end

        target_id = existing ? existing["id"] : record["id"]
        if existing
          @store.delete(FEE_MARKUP, record["id"])
          timestamps = default_timestamps(existing["created_at"])
        end

        defaults = compact_hash(
          "company_id" => company_id,
          "created_at" => timestamps["created_at"],
          "fee_type" => fee_type,
          "fixed_fee_usd" => record.key?("fixed_fee_usd") ? record["fixed_fee_usd"] : payload["fixed_fee_usd"],
          "metadata" => record["metadata"] || payload["metadata"] || {},
          "notes" => record["notes"] || payload["notes"],
          "percentage_fee" => record.key?("percentage_fee") ? record["percentage_fee"] : payload["percentage_fee"],
          "updated_at" => timestamps["updated_at"]
        )

        if existing
        end
        @store.update(FEE_MARKUP, target_id, defaults)

        @store.find(FEE_MARKUP, target_id) || record
      end

      def ensure_topup_graph(record, payload)
        company_id = record["company_id"] || payload["company_id"]
        ensure_company_exists(company_id, record["company"] || payload["company"])
        payment_method_id = record["payment_method_id"] || payload["payment_method_id"]
        payment_method = ensure_payment_method_exists(payment_method_id, payload["payment_method"])
        timestamps = default_timestamps(record["created_at"])

        defaults = compact_hash(
          "company_id" => company_id,
          "created_at" => timestamps["created_at"],
          "currency" => record["currency"] || payload["currency"] || "usd",
          "failure_message" => record["failure_message"] || payload["failure_message"],
          "paid_at" => record["paid_at"] || timestamps["created_at"],
          "payment_method_id" => payment_method_id,
          "payment_method" => compact_payment_method(payment_method),
          "status" => (record["status"] == "active" ? nil : record["status"]) || payload["status"] || "paid",
          "total" => payload["amount"] || record["total"],
          "updated_at" => timestamps["updated_at"]
        )

        @store.update(TOPUP, record["id"], defaults)
        @store.find(TOPUP, record["id"]) || record
      end

      def boolean_value(record, payload, key, default)
        return record[key] if record.key?(key)
        return payload[key] if payload.key?(key)

        default
      end

      def checkout_purchase_url(checkout_configuration_id, plan_id: nil)
        if plan_id
          "/checkout/#{plan_id}?session=#{checkout_configuration_id}"
        else
          "/checkout/setup?session=#{checkout_configuration_id}"
        end
      end

      def account_link_url(account_link_id, company_id:, use_case:)
        "https://whop.test/companies/#{company_id}/account_links/#{use_case}?session=#{account_link_id}"
      end
    end
  end
end
