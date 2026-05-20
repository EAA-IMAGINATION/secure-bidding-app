# frozen_string_literal: true

module SecureBiddingApp
  # Service to update an existing project (admin only)
  class UpdateProject
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, title:, budget_cents:, state:)
      validate_params(title, budget_cents, state)

      client = ApiClient.new(@config.API_URL)
      body = {
        title: title,
        budget_cents: budget_cents,
        state: state
      }

      response = client.patch("/projects/#{project_id}", body)
      response
    rescue ApiClient::ApiError => e
      if e.body.is_a?(Hash) && e.body['error']
        raise ValidationError, e.body['error']
      end

      raise ServiceError, "Failed to update project: #{e.message}"
    end

    private

    def validate_params(title, budget_cents, state)
      raise ValidationError, 'Title cannot be empty' if title.to_s.strip.empty?
      raise ValidationError, 'Budget must be a non-negative integer' unless budget_cents.to_s.match?(/\A\d+\z/)
      raise ValidationError, "State must be 'saved' or 'published'" unless %w[saved published].include?(state)
    end
  end
end
