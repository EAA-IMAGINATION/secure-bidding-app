# frozen_string_literal: true

module SecureBiddingApp
  # Authenticate user credentials against the Secure Bidding API
  # Returns the account attributes hash with embedded roles
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end

    def initialize
      # Service is initialized without external dependencies
      # Dependencies injected when call() is invoked
    end

    def call(email, password)
      validate_params(email, password)
      # Placeholder: actual API call would go here
      # For GREEN phase, we're just validating parameters
      nil
    end

    private

    def validate_params(email, password)
      raise ArgumentError, 'Email is required' if email.to_s.strip.empty?
      raise ArgumentError, 'Password is required' if password.to_s.empty?
    end
  end
end
