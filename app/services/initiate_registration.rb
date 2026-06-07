# frozen_string_literal: true

module SecureBiddingApp
  # Starts the registration flow by checking availability and emailing verification token.
  class InitiateRegistration
    class ValidationError < StandardError; end
    class UnavailableError < StandardError; end

    def initialize(config)
      @availability = CheckAccountAvailability.new(config)
      @client = ApiClient.new(config.API_URL)
    end

    def call(username:, email:)
      validate(username, email)
      @availability.call(username: username, email: email)
      @client.post('/auth/register', SignedMessage.sign({ username: username, email: email }))
    rescue CheckAccountAvailability::ValidationError => e
      raise ValidationError, e.message
    rescue CheckAccountAvailability::UnavailableError => e
      raise UnavailableError, e.message
    end

    private

    def validate(username, email)
      raise ValidationError, 'Username is required' if username.to_s.strip.empty?
      raise ValidationError, 'Email is required' if email.to_s.strip.empty?
    end
  end
end
