# frozen_string_literal: true

module SecureBiddingApp
  # Checks whether a username and email are available for registration.
  class CheckAccountAvailability
    class ValidationError < StandardError; end
    class UnavailableError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config.API_URL)
    end

    def call(username:, email:)
      validate(username, email)

      response = @client.post('/auth/availability', { username: username, email: email })
      ensure_available!(response)
      response
    rescue ApiClient::ApiError => e
      raise UnavailableError, e.message
    end

    private

    def validate(username, email)
      raise ValidationError, 'Username is required' if username.to_s.strip.empty?
      raise ValidationError, 'Email is required' if email.to_s.strip.empty?
    end

    def ensure_available!(response)
      available = response.is_a?(Hash) ? response['available'] || response[:available] : nil
      return if available.nil?
      return if available.values.all? { |value| value.nil? || value == true }

      raise UnavailableError, 'Username or email is already taken'
    end
  end
end
