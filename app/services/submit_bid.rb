# frozen_string_literal: true

module SecureBiddingApp
  # Service to submit a bid on a project
  class SubmitBid
    class ValidationError < StandardError; end
    class AuthorizationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, bidder_account_id:, contractor_alias:, plaintext_bid:, auth_token:)
      validate_params(bidder_account_id, contractor_alias, plaintext_bid)

      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )

      body = {
        bidder_account_id: bidder_account_id,
        contractor_alias: contractor_alias,
        plaintext_bid: plaintext_bid
      }

      response = client.post("/projects/#{project_id}/bids", body)
      response
    rescue ApiClient::ApiError => e
      if e.status == 403
        if e.body.is_a?(Hash) && e.body['error']
          raise AuthorizationError, e.body['error']
        end

        raise AuthorizationError, 'You are not authorized to bid on this project'
      end

      if e.body.is_a?(Hash) && e.body['error']
        raise ValidationError, e.body['error']
      end

      raise ServiceError, "Failed to submit bid: #{e.message}"
    end

    private

    def validate_params(bidder_account_id, contractor_alias, plaintext_bid)
      raise ValidationError, 'Bidder account ID is required' if bidder_account_id.to_s.strip.empty?
      raise ValidationError, 'Contractor alias is required' if contractor_alias.to_s.strip.empty?
      raise ValidationError, 'Bid amount is required' if plaintext_bid.to_s.strip.empty?
    end
  end
end
