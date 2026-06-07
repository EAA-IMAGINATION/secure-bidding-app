# frozen_string_literal: true

module SecureBiddingApp
  # Completes registration or existing-account email verification via the API.
  class CompleteVerification
    class VerificationError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config.API_URL)
    end

    def call(registration_token:, password: nil)
      validate(registration_token)

      payload = { registration_token: registration_token }
      payload[:password] = password.to_s unless password.nil?
      @client.post('/auth/verify', SignedMessage.sign(payload))
    rescue ApiClient::ApiError => e
      raise VerificationError, api_error_message(e)
    end

    private

    def validate(registration_token)
      return unless registration_token.to_s.strip.empty?

      raise VerificationError, 'Verification link is invalid'
    end

    def api_error_message(error)
      return error.body['error'].to_s if error.body.is_a?(Hash) && error.body['error']
      return error.body['message'].to_s if error.body.is_a?(Hash) && error.body['message']

      'Verification failed'
    end
  end
end
