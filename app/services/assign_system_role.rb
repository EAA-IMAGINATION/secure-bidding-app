# frozen_string_literal: true

module SecureBiddingApp
  # Assign system roles to an account
  class AssignSystemRole
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(account_id:, system_role:)
      validate(system_role)
      payload = { system_role: system_role }
      @client.post("/accounts/#{account_id}/system_roles", payload)
    rescue ApiClient::ApiError => e
      if e.body.is_a?(Hash) && e.body['error']
        raise ValidationError, e.body['error']
      end

      raise ServiceError, "Failed to assign role: #{e.message}"
    end

    private

    def validate(system_role)
      raise ValidationError, 'System role is required' if system_role.to_s.strip.empty?
      raise ValidationError, "System role must be 'admin' or 'user'" unless %w[admin user].include?(system_role)
    end
  end
end
