# frozen_string_literal: true

module SecureBiddingApp
  # Service to fetch projects from the API
  class FetchProjects
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(auth_token: nil, scope: :published)
      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token

      client = ApiClient.new(@config.API_URL, default_headers: headers)

      endpoint = case scope
                 when :user_projects
                   '/projects/my'
                 when :published
                   '/projects'
                 else
                   '/projects'
                 end

      response = client.get(endpoint)
      Project.from_array(response['projects'] || [])
    rescue ApiClient::ApiError => e
      raise ServiceError, "Failed to fetch projects: #{e.message}"
    end
  end
end
