# frozen_string_literal: true

module SecureBiddingApp
  # Loads username, email, and purpose for any verification token from the API.
  class FetchVerificationPreview
    class PreviewError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config.API_URL)
    end

    def call(registration_token:)
      raise PreviewError, 'Verification token is required' if registration_token.to_s.strip.empty?

      @client.post('/auth/verification-preview',
                   SignedMessage.sign({ registration_token: registration_token }))
    rescue ApiClient::ApiError => e
      raise PreviewError, api_error_message(e)
    end

    private

    def api_error_message(error)
      return error.body['error'].to_s if error.body.is_a?(Hash) && error.body['error']
      return error.body['message'].to_s if error.body.is_a?(Hash) && error.body['message']

      'Verification link is invalid or has expired'
    end
  end
end
