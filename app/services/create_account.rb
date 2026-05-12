# frozen_string_literal: true

module SecureBiddingApp
  # Create a new account via the Secure Bidding API
  class CreateAccount
    class ValidationError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(email:, username:, password:)
      validate(email, username, password)
      @client.post('/accounts', { email: email, username: username, password: password })
    rescue ApiClient::ApiError => e
      raise e
    end

    private

    def validate(email, username, password)
      raise ValidationError, 'Email required' if email.to_s.strip.empty?
      raise ValidationError, 'Username required' if username.to_s.strip.empty?
      raise ValidationError, 'Password required' if password.to_s.empty?
    end
  end
end
