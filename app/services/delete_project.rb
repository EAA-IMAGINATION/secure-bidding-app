# frozen_string_literal: true

module SecureBiddingApp
  # Service to delete a project (admin only)
  class DeleteProject
    class NotFoundError < StandardError; end
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id:)
      client = ApiClient.new(@config.API_URL)
      client.delete("/projects/#{project_id}")
    rescue ApiClient::ApiError => e
      if e.status == 404
        raise NotFoundError, 'Project not found'
      end

      raise ServiceError, "Failed to delete project: #{e.message}"
    end
  end
end
