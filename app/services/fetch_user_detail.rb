# frozen_string_literal: true

module SecureBiddingApp
  # Fetch a single user by ID
  class FetchUserDetail
    class NotFoundError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(user_id)
      @client.get("/accounts/#{user_id}")
    rescue ApiClient::ApiError => e
      raise NotFoundError, 'User not found' if e.status == 404
      raise ServiceError, "Failed to fetch user: #{e.message}"
    end
  end
end
