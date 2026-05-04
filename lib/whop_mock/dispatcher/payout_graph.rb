# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module PayoutGraph
      private

      def ensure_transfer_graph(record, payload)
        origin_id = payload["origin_id"] || record["origin_id"]
        destination_id = payload["destination_id"] || record["destination_id"]

        origin_company = company_like_id?(origin_id) ? ensure_company_exists(origin_id) : nil
        destination_company = company_like_id?(destination_id) ? ensure_company_exists(destination_id) : nil

        transfer_updates = compact_hash(
          "created_at" => record["created_at"] || Time.now.utc.iso8601,
          "updated_at" => record["updated_at"] || record["created_at"] || Time.now.utc.iso8601,
          "company_id" => record["company_id"] || origin_company&.fetch("id", nil),
          "currency" => payload["currency"] || record["currency"] || "usd",
          "amount" => record["amount"] || payload["amount"] || 10.0,
          "destination_id" => destination_id,
          "origin_id" => origin_id,
          "destination_ledger_account_id" => record["destination_ledger_account_id"] || "ledger_#{destination_id}",
          "origin_ledger_account_id" => record["origin_ledger_account_id"] || "ledger_#{origin_id}",
          "destination" => compact_transfer_party(destination_id, company: destination_company),
          "origin" => compact_transfer_party(origin_id, company: origin_company),
          "metadata" => record["metadata"] || payload["metadata"] || {},
          "notes" => record["notes"] || payload["notes"],
          "status" => record["status"] || "paid"
        )

        @store.update("transfer", record["id"], transfer_updates)
        @store.find("transfer", record["id"]) || record
      end

      def ensure_withdrawal_graph(record, payload)
        company_id = payload["company_id"] || record["company_id"]
        company = ensure_company_exists(company_id)
        payout_method_id = payload["payout_method_id"] || record["payout_method_id"]
        payout_method = payout_method_id && @store.find("payout_method", payout_method_id)

        withdrawal_updates = compact_hash(
          "created_at" => record["created_at"] || Time.now.utc.iso8601,
          "updated_at" => record["updated_at"] || record["created_at"] || Time.now.utc.iso8601,
          "amount" => record["amount"] || payload["amount"] || 10.0,
          "company_id" => company_id,
          "currency" => payload["currency"] || record["currency"] || "usd",
          "payout_method_id" => payout_method_id,
          "ledger_account" => {
            "id" => record.dig("ledger_account", "id") || "ledger_#{company_id}",
            "company_id" => company&.fetch("id", nil)
          },
          "payout_token" => {
            "id" => payout_method_id || "pomethod_example",
            "created_at" => payout_method&.fetch("created_at", nil) || record["created_at"] || Time.now.utc.iso8601,
            "destination_currency_code" => (payload["currency"] || record["currency"] || "usd").to_s,
            "nickname" => payout_method&.fetch("nickname", nil),
            "payer_name" => payout_method&.dig("destination", "name") || company&.fetch("title", nil)
          },
          "status" => record["status"] || "requested",
          "speed" => record["speed"] || "standard",
          "fee_amount" => record["fee_amount"] || 0.0,
          "markup_fee" => record["markup_fee"] || 0.0
        )

        @store.update("withdrawal", record["id"], withdrawal_updates)
        @store.find("withdrawal", record["id"]) || record
      end

      def company_like_id?(identifier)
        identifier.to_s.start_with?("biz_", "company_", "cmp_")
      end
    end
  end
end
