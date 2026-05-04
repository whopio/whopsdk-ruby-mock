# frozen_string_literal: true

module WhopMock
  class Dispatcher
    module Serializers
      private

      def compact_company(company)
        return nil unless company.is_a?(Hash)

        compact_hash(
          "id" => company["id"],
          "title" => company["title"],
          "route" => company["route"]
        )
      end

      def compact_product(product)
        return nil unless product.is_a?(Hash)

        compact_hash(
          "id" => product["id"],
          "title" => product["title"],
          "company_id" => product["company_id"],
          "company" => compact_company(product["company"])
        )
      end

      def compact_plan(plan)
        return nil unless plan.is_a?(Hash)

        compact_hash(
          "id" => plan["id"],
          "title" => plan["title"],
          "currency" => plan["currency"],
          "product_id" => plan["product_id"],
          "product" => compact_product(plan["product"])
        )
      end

      def compact_user(user, member_id: nil)
        base = user.is_a?(Hash) ? user : {}
        identifier = member_id || base["id"]
        return nil if identifier.nil?

        compact_hash(
          "id" => identifier,
          "email" => base["email"] || "#{identifier}@example.com",
          "name" => base["name"] || "Example User",
          "username" => base["username"] || identifier.to_s
        )
      end

      def compact_transfer_party(id, company: nil, user: nil)
        return nil if id.nil?

        if company.is_a?(Hash)
          compact_hash(
            "id" => company["id"] || id,
            "route" => company["route"] || "example-route",
            "title" => company["title"] || "Example",
            "typename" => "Company"
          )
        else
          compact_hash(
            "id" => (user.is_a?(Hash) ? user["id"] : id),
            "name" => user.is_a?(Hash) ? user["name"] : "Example User",
            "username" => user.is_a?(Hash) ? user["username"] : id.to_s,
            "typename" => "User"
          )
        end
      end

      def compact_member(member, member_id: nil)
        base = member.is_a?(Hash) ? member : {}
        identifier = member_id || base["id"]
        return nil if identifier.nil?

        compact_hash(
          "id" => identifier,
          "phone" => base["phone"]
        )
      end

      def compact_payment_method(payment_method)
        return nil unless payment_method.is_a?(Hash)

        card = payment_method["card"].is_a?(Hash) ? payment_method["card"] : {}
        compact_hash(
          "id" => payment_method["id"],
          "brand" => payment_method["brand"] || card["brand"],
          "card" => compact_hash(
            "brand" => payment_method["brand"] || card["brand"],
            "exp_month" => payment_method["exp_month"] || card["exp_month"],
            "exp_year" => payment_method["exp_year"] || card["exp_year"],
            "last4" => payment_method["last4"] || card["last4"]
          ),
          "country" => payment_method["country"],
          "created_at" => payment_method["created_at"],
          "exp_month" => payment_method["exp_month"] || card["exp_month"],
          "exp_year" => payment_method["exp_year"] || card["exp_year"],
          "last4" => payment_method["last4"] || card["last4"],
          "payment_method_type" => payment_method["payment_method_type"]
        )
      end

      def compact_membership(membership)
        return nil unless membership.is_a?(Hash)

        compact_hash(
          "id" => membership["id"],
          "status" => membership["status"]
        )
      end

      def compact_hash(hash)
        hash.each_with_object({}) do |(key, value), memo|
          memo[key] = value unless value.nil?
        end
      end
    end
  end
end
