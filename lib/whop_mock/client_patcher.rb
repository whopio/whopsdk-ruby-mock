# frozen_string_literal: true

module WhopMock
  class ClientPatcher
    STORAGE_IVAR = :@__whop_mock_original_requester
    REQUESTER_IVAR = :@requester

    def initialize(client, mock_requester)
      @client = client
      @mock_requester = mock_requester
    end

    def install!
      ensure_requester!
      @client.instance_variable_set(STORAGE_IVAR, @client.instance_variable_get(REQUESTER_IVAR))
      @client.instance_variable_set(REQUESTER_IVAR, @mock_requester)
    end

    def uninstall!
      original = @client.instance_variable_get(STORAGE_IVAR)
      return unless original

      @client.instance_variable_set(REQUESTER_IVAR, original)
      @client.remove_instance_variable(STORAGE_IVAR)
    end

    private

    def ensure_requester!
      return if @client.instance_variable_defined?(REQUESTER_IVAR)

      raise Error, "Client does not expose #{@client.class}#{REQUESTER_IVAR} for mock installation"
    end
  end
end
