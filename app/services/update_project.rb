# frozen_string_literal: true

module SecureBiddingApp
  # Service to update an existing project (admin only)
  class UpdateProject
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, title:, budget_cents:, state:, auth_token: nil)
      validate_params(title, budget_cents, state)

      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token

      client = ApiClient.new(@config.API_URL, default_headers: headers)
      body = {
        title: title,
        budget_cents: budget_cents,
        state: state
      }

      client.patch("/projects/#{project_id}", body)
    rescue ApiClient::ApiError => e
      raise ValidationError, e.body['error'] if e.body.is_a?(Hash) && e.body['error']

      raise ServiceError, "Failed to update project: #{e.message}"
    end

    private

    def validate_params(title, budget_cents, state)
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
