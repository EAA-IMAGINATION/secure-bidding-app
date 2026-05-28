# frozen_string_literal: true

module SecureBiddingApp
  # Fetch all users from the API
  class FetchUsers
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    # Accept an optional auth_token to include in the request headers
    def call(auth_token: nil)
      headers = {}
      if auth_token && !auth_token.to_s.strip.empty?
        headers['Authorization'] = "Bearer #{auth_token}"
      end

      res = @client.get('/accounts', headers: headers)
      Account.from_array(res['accounts'] || [])
    rescue ApiClient::ApiError => e
      raise ServiceError, "Failed to fetch users: #{e.message}"
    end
  end
end
