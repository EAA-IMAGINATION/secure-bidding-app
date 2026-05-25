# frozen_string_literal: true

module SecureBiddingApp
  # Assign system roles to an account
  class AssignSystemRole
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end
    VALID_ROLES = %w[system_admin project_owner bidder].freeze

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(account_id:, system_role:)
      validate(system_role)
      payload = { role: system_role }
      @client.post("/accounts/#{account_id}/system_roles", payload)
    rescue ApiClient::ApiError => e
      raise ValidationError, e.body['error'] if e.body.is_a?(Hash) && e.body['error']

      raise ServiceError, "Failed to assign role: #{e.message}"
    end

    private

    def validate(system_role)
      raise ValidationError, 'System role is required' if system_role.to_s.strip.empty?

      return if VALID_ROLES.include?(system_role)

      raise ValidationError, "System role must be one of: #{VALID_ROLES.join(', ')}"
    end
  end
end
