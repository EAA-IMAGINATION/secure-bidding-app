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
    end

    private

    def validate(registration_token)
      return unless registration_token.to_s.strip.empty?

      raise ValidationError,
            'Registration token is required'
    end
  end
end
