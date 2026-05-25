# frozen_string_literal: true

module SecureBiddingApp
  # Update an existing account
  class UpdateAccount
    class ValidationError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(user_id:, email:, auth_token: nil)
      validate(email)
      
      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token
      
      payload = { email: email }
      client = auth_token ? ApiClient.new(@config.API_URL, default_headers: headers) : @client
      client.patch("/accounts/#{user_id}", payload)
    rescue ApiClient::ApiError => e
      raise ValidationError, e.body['error'] if e.body.is_a?(Hash) && e.body['error']

      raise ServiceError, "Failed to update account: #{e.message}"
    end

    private

    def validate(email)
      raise ValidationError, 'Email is required' if email.to_s.strip.empty?
    end
  end
end
