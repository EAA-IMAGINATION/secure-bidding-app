# frozen_string_literal: true

module SecureBiddingApp
  # Service to fetch a single published project
  class FetchProjectDetail
    class ServiceError < StandardError; end
    class NotFoundError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id)
      client = ApiClient.new(@config.API_URL)
      res = client.get("/projects/#{project_id}")
      Project.from_hash(res)
    rescue ApiClient::ApiError => e
      raise NotFoundError, 'Project not found' if e.status == 404

      raise ServiceError, "Failed to fetch project: #{e.message}"
    end
  end
end
