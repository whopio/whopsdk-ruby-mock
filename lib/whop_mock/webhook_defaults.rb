# frozen_string_literal: true

module WhopMock
  class WebhookSimulator
    module WebhookDefaults
      include ResourceNames

      private

      def resource_name_for(event_type)
        prefix = event_type.to_s.split(".").first.to_s
        RESOURCE_OVERRIDES.fetch(prefix) do
          prefix.end_with?("ies") ? "#{prefix[0...-3]}y" : prefix.sub(/s$/, "")
        end
      end

      def default_attributes_for(resource_name, event_type)
        suffix = event_type.to_s.split(".")[1].to_s
        STATUS_PROFILES.fetch(resource_name, {}).fetch(suffix, fallback_defaults(resource_name))
      end

      def fallback_defaults(resource_name)
        case ResourceNames.normalize(resource_name)
        when MEMBERSHIP then { "status" => "active" }
        when PAYMENT then { "status" => "paid", "substatus" => "succeeded" }
        when INVOICE then { "status" => "draft" }
        when REFUND then { "status" => "succeeded" }
        when SETUP_INTENT then { "status" => "succeeded" }
        else { "status" => "created" }
        end
      end
    end
  end
end
