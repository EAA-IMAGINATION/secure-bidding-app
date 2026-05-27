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

    def call(user_id:, username: nil, email: nil, password: nil, auth_token: nil)
      payload = build_payload(username: username, email: email, password: password)
      validate_payload!(payload)

      client = client_with_auth(auth_token)
      client.patch("/accounts/#{user_id}", payload)
    end

    private

    def client_with_auth(auth_token)
      return @client if auth_token.to_s.strip.empty?

      ApiClient.new(@config.API_URL, default_headers: { 'Authorization' => "Bearer #{auth_token}" })
    end

    def build_payload(username:, email:, password:)
      payload = {}
      payload[:username] = username.to_s.strip unless username.to_s.strip.empty?
      payload[:email] = email.to_s.strip unless email.to_s.strip.empty?
      payload[:password] = password.to_s unless password.to_s.empty?
      payload
    end

    def validate_payload!(payload)
      raise ValidationError, 'At least one field is required' if payload.empty?
    end
  end
end
