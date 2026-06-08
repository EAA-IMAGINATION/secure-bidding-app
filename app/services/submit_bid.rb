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

    def call(project_id:, bidder_account_id:, contractor_alias:, encrypted_bid_amount:, encrypted_proposal_text:, auth_token:, encrypted_document: nil, document_file_name: nil, document_file_hash: nil)
      validate_params(bidder_account_id, contractor_alias, encrypted_bid_amount, encrypted_proposal_text)
      encrypted_bid = parse_encrypted_payload(encrypted_bid_amount, 'encrypted bid amount')
      encrypted_proposal = parse_encrypted_payload(encrypted_proposal_text, 'encrypted proposal text')

      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )

      body = {
        bidder_account_id: bidder_account_id,
        contractor_alias: contractor_alias,
        encrypted_bid_amount: encrypted_bid,
        encrypted_proposal_text: encrypted_proposal
      }

      if encrypted_document && !encrypted_document.to_s.strip.empty?
        body[:encrypted_document] = parse_encrypted_payload(encrypted_document, 'encrypted document')
        body[:document_file_name] = document_file_name
        body[:document_file_hash] = document_file_hash
      end

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

    def parse_encrypted_payload(value, label)
      return value if value.is_a?(Hash)

      JSON.parse(value.to_s)
    rescue JSON::ParserError
      raise ValidationError, "Invalid #{label} payload"
    end

    def validate_params(bidder_account_id, contractor_alias, encrypted_bid_amount, encrypted_proposal_text)
      raise ValidationError, 'Bidder account ID is required' if bidder_account_id.to_s.strip.empty?
      raise ValidationError, 'Bidder account ID must be a valid UUID' unless bidder_account_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      raise ValidationError, 'Contractor alias is required' if contractor_alias.to_s.strip.empty?
      raise ValidationError, 'Encrypted bid amount is required' if encrypted_bid_amount.to_s.strip.empty?
      raise ValidationError, 'Encrypted proposal text is required' if encrypted_proposal_text.to_s.strip.empty?
    end
  end
end
