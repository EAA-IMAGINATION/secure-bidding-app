# frozen_string_literal: true

module SecureBiddingApp
  # Service to create a new project
  class CreateProject
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(title:, budget_cents:, state: 'saved', owner_account_id: nil)
      validate_params(title, budget_cents, state)

      client = ApiClient.new(@config.API_URL)
      body = {
        title: title,
        budget_cents: budget_cents,
        state: state
      }
      body['owner_account_id'] = owner_account_id if owner_account_id

      response = client.post('/projects', body)
      response
    rescue ApiClient::ApiError => e
      if e.body.is_a?(Hash) && e.body['error']
        raise ValidationError, e.body['error']
      end

      raise ServiceError, "Failed to create project: #{e.message}"
    end

    private

    def validate_params(title, budget_cents, state)
      raise ValidationError, 'Title cannot be empty' if title.to_s.strip.empty?
      raise ValidationError, 'Budget must be a non-negative integer' unless budget_cents.to_s.match?(/\A\d+\z/)
      raise ValidationError, "State must be 'saved' or 'published'" unless %w[saved published].include?(state)
    end
  end
end
