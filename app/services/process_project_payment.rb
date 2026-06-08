# frozen_string_literal: true

module SecureBiddingApp
  class ProcessProjectPayment
    class ServiceError < StandardError; end
    class AuthorizationError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, auth_token:)
      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )
      client.post("/projects/#{project_id}/process_payment", {})
    rescue ApiClient::ApiError => e
      raise AuthorizationError, e.body['error'] if e.status == 403
      raise ServiceError, e.body.is_a?(Hash) ? e.body['error'] : e.message
    end
  end
end
