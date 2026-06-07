# frozen_string_literal: true

module SecureBiddingApp
  # Create a new account via the Secure Bidding API
  class CreateAccount
    class ValidationError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(email:, username:, password:, verification_token: nil)
      validate(email, username, password)
      payload = { email: email, username: username, password: password }
      payload[:verification_token] = verification_token if verification_token
      @client.post('/accounts', SignedMessage.sign(payload))
    end

    private

    def validate(email, username, password)
      raise ValidationError, 'Email required' if email.to_s.strip.empty?
      raise ValidationError, 'Username required' if username.to_s.strip.empty?
      raise ValidationError, 'Password required' if password.to_s.empty?
    end
  end
end
