# frozen_string_literal: true

module SecureBiddingApp
  # Service to fetch published projects from the API
  class FetchProjects
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call
      client = ApiClient.new(@config.API_URL)
      response = client.get('/projects')
      response['projects'] || []
    rescue ApiClient::ApiError => e
      raise ServiceError, "Failed to fetch projects: #{e.message}"
    end
  end
end
