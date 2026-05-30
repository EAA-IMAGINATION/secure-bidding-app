# frozen_string_literal: true

module SecureBiddingApp
  class FetchProjectMilestones
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id, auth_token:)
      headers = { 'Authorization' => "Bearer #{auth_token}" }
      client = ApiClient.new(@config.API_URL, default_headers: headers)
      client.get("/projects/#{project_id}/milestones")
    rescue ApiClient::ApiError => e
      raise ServiceError, "Failed to fetch milestones: #{e.message}" if e.status != 404

      { 'milestones' => [] }
    end
  end
end
