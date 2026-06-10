# frozen_string_literal: true

module SecureBiddingApp
  # Service to create a new project
  class CreateProject
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(title:, budget_cents:, state: 'saved', description: nil, required_documents: [], bidding_deadline: nil, nacl_public_key: nil, nacl_encrypted_private_key: nil, auth_token: nil)
      validate_params(title, budget_cents, state, bidding_deadline)

      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token

      client = ApiClient.new(@config.API_URL, default_headers: headers)
      body = {
        title: title,
        description: description,
        required_documents: required_documents,
        budget_cents: budget_cents,
        state: state,
        bidding_deadline: bidding_deadline,
        nacl_public_key: nacl_public_key,
        nacl_encrypted_private_key: nacl_encrypted_private_key
      }

      client.post('/projects', body)
    rescue ApiClient::ApiError => e
      raise ValidationError, e.body['error'] if e.body.is_a?(Hash) && e.body['error']

      raise ServiceError, "Failed to create project: #{e.message}"
    end

    private

    def validate_params(title, budget_cents, state, bidding_deadline)
      raise ValidationError, 'Title cannot be empty' if title.to_s.strip.empty?
      unless budget_cents.to_s.match?(/\A\d+\z/)
        raise ValidationError,
              'Budget must be a non-negative integer'
      end

      return if %w[saved published].include?(state)

      raise ValidationError, "State must be 'saved' or 'published'"
    end
  end
end
