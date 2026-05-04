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
      validate_params(username, password)
      fetch_and_format_account(username)
    rescue ApiClient::ApiError => e
      handle_api_error(e)
    end

    private

    def validate_params(username, password)
      return unless username.to_s.strip.empty? || password.to_s.empty?

      raise UnauthorizedError, 'Username and password required'
    end

    def fetch_and_format_account(username)
      response = @client.get('/accounts/search', params: { email: username })
      raise UnauthorizedError, 'Account not found' if response.empty? || response['id'].nil?

      format_account(response)
    end

    def format_account(response)
      {
        'id' => response['id'],
        'username' => response['username'],
        'email' => response['email'],
        'include' => response['include'] || { 'system_roles' => [] }
      }
    end

    def handle_api_error(error)
      raise UnauthorizedError, "Authentication failed: #{error.message}" if error.status == 403

      raise
    end
  end
end
