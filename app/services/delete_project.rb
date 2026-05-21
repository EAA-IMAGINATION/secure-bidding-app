# frozen_string_literal: true

module SecureBiddingApp
  # Service to delete a project (admin only)
  class DeleteProject
    class NotFoundError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:, auth_token: nil)
      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token

      client = ApiClient.new(@config.API_URL, default_headers: headers)
      client.delete("/projects/#{project_id}")
    rescue ApiClient::ApiError => e
      raise NotFoundError, 'Project not found' if e.status == 404

      raise ServiceError, "Failed to delete project: #{e.message}"
    end
  end
end
