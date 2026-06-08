# frozen_string_literal: true

module SecureBiddingApp
  class AwardProjectBid
    class ServiceError < StandardError; end
    class AuthorizationError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, bid_submission_id:, awarded_bid_amount_cents:, auth_token:)
      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )
      client.post(
        "/projects/#{project_id}/award",
        {
          bid_submission_id: bid_submission_id,
          awarded_bid_amount_cents: awarded_bid_amount_cents
        }
      )
    rescue ApiClient::ApiError => e
      raise AuthorizationError, e.body['error'] if e.status == 403
      raise ServiceError, api_error_message(e)
    end

    private

    def api_error_message(error)
      return error.body['error'] if error.body.is_a?(Hash) && error.body['error']

      error.message
    end
  end
end
