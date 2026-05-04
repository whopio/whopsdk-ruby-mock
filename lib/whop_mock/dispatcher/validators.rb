# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module Validators
      include ResourceNames

      private

      def validate_create_payload!(route, payload)
        resource_name = ResourceNames.normalize(route.resource_name)
        case resource_name
        when COMPANY
          require_fields!(route, payload, "title")
        when TOPUP
          require_fields!(route, payload, "amount", "company_id", "currency", "payment_method_id")
          validate_topup_payload!(route, payload)
        when FEE_MARKUP
          require_fields!(route, payload, "company_id", "fee_type")
          validate_fee_markup_payload!(route, payload)
        when PRODUCT
          require_fields!(route, payload, "company_id", "title")
        when PLAN
          require_fields!(route, payload, "company_id", "product_id", "title")
        when PAYMENT_METHOD
          validate_payment_method_payload!(route, payload)
        when PAYMENT
          validate_payment_payload!(route, payload)
        when INVOICE
          validate_invoice_payload!(route, payload)
        end

        validate_schema_payload!(route, payload, require_required: true)
      end

      def validate_update_payload!(route, current, attributes)
        case ResourceNames.normalize(route.resource_name)
        when INVOICE
          validate_invoice_update_payload!(route, current, attributes)
        when PLAN
          validate_plan_update_payload!(route, attributes)
        end

        validate_schema_payload!(route, attributes, require_required: false)
      end

      def validate_list_query!(route, query)
        params = stringify_keys(query || {})
        validate_direction!(route, params)

        case ResourceNames.normalize(route.resource_name)
        when PRODUCT, PLAN, SETUP_INTENT, WEBHOOK, PAYOUT_METHOD, WITHDRAWAL, CHECKOUT_CONFIGURATION, FEE_MARKUP, DISPUTE, DISPUTE_ALERT
          require_fields!(route, params, "company_id")
        when PAYMENT_METHOD
          has_company = present_value?(params["company_id"])
          has_member = present_value?(params["member_id"])
          raise validation_error("payment_method list requires exactly one of company_id or member_id", route: route) unless has_company ^ has_member
        when MEMBER
          validate_member_list_query!(route, params)
        when PROMO_CODE
          validate_promo_code_list_query!(route, params)
        when TRANSFER
          validate_transfer_list_query!(route, params)
        end
      end

      def validate_action!(route, current, attributes)
        case [ResourceNames.normalize(route.resource_name), route.action.to_s]
        when [MEMBERSHIP, "pause"]
          if current["status"] == "canceled" || current["payment_collection_paused"] == true
            reason = current["status"] == "canceled" ? "canceled state" : "already paused"
            raise invalid_combination_error("cannot pause membership: #{reason}",
                                            route: route)
          end
        when [MEMBERSHIP, "resume"]
          unless current["payment_collection_paused"] == true
            raise invalid_combination_error("cannot resume membership that is not paused",
                                            route: route)
          end
        when [MEMBERSHIP, "uncancel"]
          unless current["status"] == "canceled"
            raise invalid_combination_error("cannot uncancel membership in #{current["status"]} state",
                                            route: route)
          end
        when [MEMBERSHIP, "add_free_days"]
          free_days = begin
            Integer(attributes.fetch("free_days", 0))
          rescue StandardError
            0
          end
          raise validation_error("free_days must be greater than 0", route: route) unless free_days.positive?
        when [PAYMENT, "refund"]
          validate_payment_refund_action!(route, current, attributes)
        when [PAYMENT, "retry"]
          unless current["status"] == "open" || %w[failed pending].include?(current["substatus"].to_s)
            raise invalid_combination_error("cannot retry payment in #{current["status"]} state", route: route)
          end
        when [PAYMENT, "void"]
          if current["status"] == "void" || current["substatus"] == "refunded"
            raise invalid_combination_error("cannot void payment in #{current["status"]} state", route: route)
          end
        when [INVOICE, "mark_paid"]
          if %w[paid refunded void].include?(current["status"].to_s)
            raise invalid_combination_error("cannot mark_paid invoice in #{current["status"]} state", route: route)
          end
        when [INVOICE, "mark_uncollectible"]
          if %w[void uncollectible].include?(current["status"].to_s)
            raise invalid_combination_error("cannot mark_uncollectible invoice in #{current["status"]} state",
                                            route: route)
          end
        when [INVOICE, "void"]
          raise invalid_combination_error("cannot void invoice in #{current["status"]} state", route: route) if %w[void refunded].include?(current["status"].to_s)
        when [DISPUTE, "submit_evidence"], [DISPUTE, "update_evidence"]
          unless current["editable"]
            raise invalid_combination_error("cannot #{route.action} dispute in #{current["status"]} state",
                                            route: route)
          end
        end
      end

      def validate_payment_method_payload!(route, payload)
        token_id = payload["payment_token"] || payload["payment_token_id"] || payload["token"]
        return unless blank_value?(token_id)

        raise validation_error("payment_method requires payment_token or payment_token_id",
                               route: route)
      end

      def validate_payment_payload!(route, payload)
        require_fields!(route, payload, "company_id", "member_id")
        if blank_value?(payload["plan_id"]) && blank_hash?(payload["plan"])
          raise validation_error("payment requires plan_id or plan",
                                 route: route)
        end
        if blank_value?(payload["payment_method_id"]) && blank_hash?(payload["payment_method"])
          raise validation_error("payment requires payment_method_id or payment_method",
                                 route: route)
        end

        plan_id = payload["plan_id"]
        plan_payload_id = payload.dig("plan", "id")
        if present_value?(plan_id) && present_value?(plan_payload_id) && plan_id.to_s != plan_payload_id.to_s
          raise invalid_combination_error("payment plan_id conflicts with plan.id", route: route)
        end

        existing_plan = present_value?(plan_id) ? @store.find("plan", plan_id) : nil
        if existing_plan && present_value?(payload["product_id"]) && payload["product_id"].to_s != field_value(
          existing_plan, "product_id"
        ).to_s
          raise invalid_combination_error("payment product_id conflicts with existing plan product", route: route)
        end
      end

      def validate_fee_markup_payload!(route, payload)
        fixed_fee = payload["fixed_fee_usd"]
        percentage_fee = payload["percentage_fee"]

        raise validation_error("fixed_fee_usd must be between 0 and 50", route: route) if present_value?(fixed_fee) && (fixed_fee.to_f.negative? || fixed_fee.to_f > 50.0)

        return unless present_value?(percentage_fee) && (percentage_fee.to_f.negative? || percentage_fee.to_f > 25.0)

        raise validation_error("percentage_fee must be between 0 and 25", route: route)
      end

      def validate_topup_payload!(route, payload)
        amount = payload["amount"].to_f
        raise validation_error("amount must be greater than 0", route: route) unless amount.positive?
      end

      def validate_invoice_payload!(route, payload)
        require_fields!(route, payload, "company_id")
        if blank_value?(payload["member_id"]) && blank_value?(payload["email_address"])
          raise validation_error("invoice requires member_id or email_address", route: route)
        end

        has_product = present_value?(payload["product_id"]) || present_value?(payload.dig("product", "id"))
        has_plan = present_value?(payload.dig("plan",
                                              "id")) || present_value?(payload.dig("current_plan",
                                                                                   "id")) || present_value?(payload["plan_id"]) || !blank_hash?(payload["plan"])
        unless has_product || has_plan
          raise validation_error("invoice requires product_id, product, or plan",
                                 route: route)
        end

        if payload["collection_method"].to_s == "charge_automatically" && blank_value?(payload["payment_token_id"])
          raise invalid_combination_error("charge_automatically invoices require payment_token_id", route: route)
        end

        plan_product_id = payload.dig("plan", "product_id")
        return unless present_value?(payload["product_id"]) && present_value?(plan_product_id) && payload["product_id"].to_s != plan_product_id.to_s

        raise invalid_combination_error("invoice product_id conflicts with plan.product_id", route: route)
      end

      def validate_invoice_update_payload!(route, current, attributes)
        plan_product_id = attributes.dig("plan", "product_id")
        if present_value?(attributes["product_id"]) && present_value?(plan_product_id) && attributes["product_id"].to_s != plan_product_id.to_s
          raise invalid_combination_error("invoice product_id conflicts with plan.product_id", route: route)
        end

        if attributes["collection_method"].to_s == "charge_automatically" &&
           blank_value?(attributes["payment_token_id"]) &&
           blank_value?(current["payment_token_id"])
          raise invalid_combination_error("charge_automatically invoices require payment_token_id", route: route)
        end
      end

      def validate_plan_update_payload!(route, attributes)
        if present_value?(attributes["initial_price"]) && attributes["initial_price"].to_f.negative?
          raise validation_error("initial_price must be greater than or equal to 0", route: route)
        end
        return unless present_value?(attributes["renewal_price"]) && attributes["renewal_price"].to_f.negative?

        raise validation_error("renewal_price must be greater than or equal to 0", route: route)
      end

      def validate_payment_refund_action!(route, current, attributes)
        requested_amount = attributes["partial_amount"] || attributes["amount"] || current["total"] || current["subtotal"]
        amount = requested_amount.to_f
        raise validation_error("refund amount must be greater than 0", route: route) unless amount.positive?

        total = (current["total"] || current["subtotal"]).to_f
        remaining = total - (current["refunded_amount"] || 0).to_f
        return unless remaining <= 0 || amount > remaining

        raise invalid_combination_error("refund amount exceeds remaining refundable amount",
                                        route: route)
      end

      def require_fields!(route, payload, *fields)
        missing = fields.select { |field| blank_value?(payload[field]) }
        raise validation_error("missing required fields: #{missing.join(", ")}", route: route) if missing.any?
      end

      def validate_member_list_query!(route, params)
        if present_value?(params["access_level"])
          allowed = %w[no_access admin customer]
          value = params["access_level"].to_s
          raise validation_error("invalid access_level: #{value}", route: route) unless allowed.include?(value)
        end

        if params["statuses"]
          allowed = %w[drafted joined left]
          invalid = Array(params["statuses"]).map(&:to_s) - allowed
          raise validation_error("invalid statuses: #{invalid.join(", ")}", route: route) if invalid.any?
        end

        if present_value?(params["order"])
          allowed = %w[id usd_total_spent created_at joined_at most_recent_action]
          value = params["order"].to_s
          raise validation_error("invalid order: #{value}", route: route) unless allowed.include?(value)
        end

        return unless params["most_recent_actions"]

        allowed = %w[canceling churned finished_split_pay paused paid_subscriber paid_once expiring joined drafted left
                     trialing pending_entry renewing past_due]
        invalid = Array(params["most_recent_actions"]).map(&:to_s) - allowed
        raise validation_error("invalid most_recent_actions: #{invalid.join(", ")}", route: route) if invalid.any?
      end

      def validate_transfer_list_query!(route, params)
        return unless present_value?(params["order"])

        allowed = %w[amount created_at]
        value = params["order"].to_s
        raise validation_error("invalid order: #{value}", route: route) unless allowed.include?(value)
      end

      def validate_promo_code_list_query!(route, params)
        require_fields!(route, params, "company_id")
        return unless present_value?(params["status"])

        allowed = %w[active inactive archived]
        value = params["status"].to_s
        raise validation_error("invalid status: #{value}", route: route) unless allowed.include?(value)
      end

      def validate_direction!(route, params)
        return unless present_value?(params["direction"])

        allowed = %w[asc desc]
        value = params["direction"].to_s
        raise validation_error("invalid direction: #{value}", route: route) unless allowed.include?(value)
      end

      def validate_schema_payload!(route, payload, require_required:)
        schema = route.request_schema
        return if schema.nil? || schema.empty? || !payload.is_a?(Hash)

        validate_schema_hash!(payload, schema, route: route, path: ResourceNames.normalize(route.resource_name),
                                               require_required: require_required)
      end

      def validate_schema_hash!(payload, schema, route:, path:, require_required:)
        resolved = schema
        properties = resolved.fetch("properties", {})
        reject_unknown_fields!(payload, properties, route: route, path: path) if properties.any?

        if require_required
          missing = Array(resolved["required"]).select { |field| blank_value?(payload[field]) }
          raise validation_error("missing required fields: #{missing.join(", ")}", route: route) if missing.any?
        end

        payload.each do |key, value|
          property_schema = properties[key]
          next if property_schema.nil?

          validate_schema_value!(value, property_schema, route: route, path: "#{path}.#{key}",
                                                         require_required: require_required)
        end
      end

      def validate_schema_value!(value, schema, route:, path:, require_required:)
        resolved = schema
        enum = resolved["enum"]
        if enum.is_a?(Array) && present_value?(value)
          if value.is_a?(Array)
            invalid = value.map(&:to_s) - enum.map(&:to_s)
            raise validation_error("invalid #{path}: #{invalid.join(", ")}", route: route) if invalid.any?
          elsif !enum.map(&:to_s).include?(value.to_s)
            raise validation_error("invalid #{path}: #{value}", route: route)
          end
        end

        case resolved["type"]
        when "object", nil
          if value.is_a?(Hash)
            validate_schema_hash!(value, resolved, route: route, path: path,
                                                   require_required: require_required)
          end
        when "array"
          item_schema = resolved["items"] || {}
          Array(value).each_with_index do |item, index|
            validate_schema_value!(item, item_schema, route: route, path: "#{path}[#{index}]",
                                                      require_required: require_required)
          end
        end
      end

      def reject_unknown_fields!(payload, properties, route:, path:)
        # Be permissive about unknown fields - the real API is the gatekeeper.
        # This handles spec/SDK mismatches (e.g., use_case vs use_cases) and
        # allows the mock to work with SDK versions that have newer fields.
        unknown = payload.keys.map(&:to_s) - properties.keys.map(&:to_s)
        return if unknown.empty?

        return unless WhopMock.configuration.debug

        WhopMock.configuration.debug_io.puts "[WhopMock] ignoring unknown fields for #{path}: #{unknown.join(", ")}"
      end

      def validation_error(message, route:)
        ErrorMapper.build(:bad_request, message, {}, route: route)
      end

      def invalid_combination_error(message, route:)
        ErrorMapper.build(:unprocessable_entity, message, {}, route: route)
      end
    end
  end
end
