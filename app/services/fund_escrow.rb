# frozen_string_literal: true

module SecureBiddingApp
  class FundEscrow
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(milestone_id:, auth_token:, payment_method_id: 'placeholder')
      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )
      client.post('/payments/escrow/fund', { milestone_id: milestone_id, payment_method_id: payment_method_id })
    rescue ApiClient::ApiError => e
      message = e.body.is_a?(Hash) && e.body['error'] ? e.body['error'] : e.message
      raise ServiceError, message
    end
  end
end
