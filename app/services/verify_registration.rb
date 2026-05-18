# frozen_string_literal: true

module SecureBiddingApp
  # Completes the registration flow using the emailed verification token.
  class VerifyRegistration
    class ValidationError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config.API_URL)
    end

    def call(registration_token:, password: nil)
      validate(registration_token)

      payload = { registration_token: registration_token }
      payload[:password] = password.to_s unless password.nil?
      @client.post('/auth/verify', payload)
    rescue ApiClient::ApiError => e
      raise e
    end

    private

    def validate(registration_token)
      raise ValidationError, 'Registration token is required' if registration_token.to_s.strip.empty?
    end
  end
end
