# frozen_string_literal: true

module SecureBiddingApp
  # Authenticate user credentials against the Secure Bidding API
  # Returns the account attributes hash with embedded roles
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end

    def initialize(config = App.config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(username:, password:)
      validate_params(username, password)
      @client.post('/auth/authenticate', { username: username, password: password })
    rescue ApiClient::ApiError => e
      raise UnauthorizedError, "Authentication failed: #{e.message}"
    end

    private

    def validate_params(username, password)
      raise ArgumentError, 'Username is required' if username.to_s.strip.empty?
      raise ArgumentError, 'Password is required' if password.to_s.empty?
    end
  end
end
