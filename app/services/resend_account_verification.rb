# frozen_string_literal: true

module SecureBiddingApp
  # Request the API to resend an account verification email.
  class ResendAccountVerification
    class ValidationError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(user_id:, auth_token: nil)
      raise ValidationError, 'Account id is required' if user_id.to_s.strip.empty?

      client = client_with_auth(auth_token)
      client.post("/accounts/#{user_id}/resend_verification", {})
    end

    private

    def client_with_auth(auth_token)
      return @client if auth_token.to_s.strip.empty?

      ApiClient.new(@config.API_URL, default_headers: { 'Authorization' => "Bearer #{auth_token}" })
    end
  end
end
