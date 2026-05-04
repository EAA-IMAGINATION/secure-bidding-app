# frozen_string_literal: true

module SecureBiddingApp
  # Authenticate user credentials against the Secure Bidding API
  # Returns the account attributes hash with embedded roles
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, password:)
      raise UnauthorizedError, 'Username and password required' if username.to_s.strip.empty? || password.to_s.empty?

      # WEEK 1 PLACEHOLDER: API does not yet have /auth/authenticate endpoint
      # For now, fetch account by username and validate password locally
      # In Week 4+, this will call a proper /auth/authenticate endpoint
      
      response = @client.get('/accounts/search', params: { email: username })
      
      # Since password validation is not yet in API, this is a stub
      # In production, verify password against a hash
      raise UnauthorizedError, 'Account not found' if response.empty? || response['id'].nil?

      {
        'id' => response['id'],
        'username' => response['username'],
        'email' => response['email'],
        'include' => response['include'] || { 'system_roles' => [] }
      }
    rescue ApiClient::ApiError => e
      raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403

      raise
    end
  end
end
