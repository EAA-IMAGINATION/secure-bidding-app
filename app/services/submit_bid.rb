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

    def call(project_id:, bidder_account_id:, contractor_alias:, encrypted_bid_amount:, encrypted_proposal_text:, auth_token:)
      validate_params(bidder_account_id, contractor_alias, encrypted_bid_amount, encrypted_proposal_text)

      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )

      # Parse encrypted JSON strings
      encrypted_bid = JSON.parse(encrypted_bid_amount)
      encrypted_proposal = JSON.parse(encrypted_proposal_text)

      body = {
        bidder_account_id: bidder_account_id,
        contractor_alias: contractor_alias,
        encrypted_bid_amount: encrypted_bid,
        encrypted_proposal_text: encrypted_proposal
      }

      client.post("/projects/#{project_id}/bids", body)
    rescue ApiClient::ApiError => e
      if e.status == 403
        raise AuthorizationError, e.body['error'] if e.body.is_a?(Hash) && e.body['error']

        raise AuthorizationError, 'You are not authorized to bid on this project'
      end

      raise ValidationError, e.body['error'] if e.body.is_a?(Hash) && e.body['error']

      raise ServiceError, "Failed to submit bid: #{e.message}"
    end

    private

    def validate_params(bidder_account_id, contractor_alias, encrypted_bid_amount, encrypted_proposal_text)
      raise ValidationError, 'Bidder account ID is required' if bidder_account_id.to_s.strip.empty?
      raise ValidationError, 'Contractor alias is required' if contractor_alias.to_s.strip.empty?
      raise ValidationError, 'Encrypted bid amount is required' if encrypted_bid_amount.to_s.strip.empty?
      raise ValidationError, 'Encrypted proposal text is required' if encrypted_proposal_text.to_s.strip.empty?
    end
  end
end
