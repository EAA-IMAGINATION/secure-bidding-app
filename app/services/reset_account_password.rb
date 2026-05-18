# frozen_string_literal: true

module SecureBiddingApp
  # Resets an account password using the API account search and update endpoints.
  class ResetAccountPassword
    class ValidationError < StandardError; end
    class NotFoundError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config.API_URL)
    end

    def call(email:, password:)
      validate(email, password)

      account = find_account(email)
      raise NotFoundError, 'No account matches that email' unless account

      @client.patch("/accounts/#{account['id']}", { password: password })
      account
    rescue ApiClient::ApiError => e
      raise e
    end

    private

    def validate(email, password)
      raise ValidationError, 'Email is required' if email.to_s.strip.empty?
      raise ValidationError, 'Password is required' if password.to_s.empty?
    end

    def find_account(email)
      response = @client.get('/accounts/search', params: { email: email })
      response.fetch('accounts', []).first
    end
  end
end
