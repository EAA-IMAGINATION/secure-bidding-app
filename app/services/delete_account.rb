# frozen_string_literal: true

module SecureBiddingApp
  # Delete an account
  class DeleteAccount
    class NotFoundError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(user_id:, auth_token: nil)
      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token
      
      client = auth_token ? ApiClient.new(@config.API_URL, default_headers: headers) : @client
      client.delete("/accounts/#{user_id}")
    rescue ApiClient::ApiError => e
      raise NotFoundError, 'User not found' if e.status == 404

      raise ServiceError, "Failed to delete account: #{e.message}"
    end
  end
end
