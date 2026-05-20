# frozen_string_literal: true

module SecureBiddingApp
  # Fetch all users from the API
  class FetchUsers
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call
      @client.get('/accounts')
    rescue ApiClient::ApiError => e
      raise ServiceError, "Failed to fetch users: #{e.message}"
    end
  end
end
