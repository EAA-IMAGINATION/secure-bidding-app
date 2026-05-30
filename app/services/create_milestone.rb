# frozen_string_literal: true

module SecureBiddingApp
  class CreateMilestone
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, title:, budget_cents:, description: nil, auth_token:)
      raise ValidationError, 'Title is required' if title.to_s.strip.empty?
      raise ValidationError, 'Budget is required' if budget_cents.to_s.strip.empty?

      client = ApiClient.new(
        @config.API_URL,
        default_headers: { 'Authorization' => "Bearer #{auth_token}" }
      )
      body = {
        title: title.to_s.strip,
        budget_cents: budget_cents.to_i,
        description: description
      }
      client.post("/projects/#{project_id}/milestones", body.compact)
    rescue ApiClient::ApiError => e
      if e.body.is_a?(Hash) && e.body['error']
        raise ValidationError, e.body['error'].is_a?(Hash) ? e.body['error'].to_s : e.body['error']
      end

      raise ServiceError, "Failed to create milestone: #{e.message}"
    end
  end
end
