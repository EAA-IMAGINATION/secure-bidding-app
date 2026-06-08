# frozen_string_literal: true

module SecureBiddingApp
  class FetchProjectBidSubmissions
    class ServiceError < StandardError; end
    class ForbiddenError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id, auth_token:)
      headers = { 'Authorization' => "Bearer #{auth_token}" }
      client = ApiClient.new(@config.API_URL, default_headers: headers)
      client.get("/projects/#{project_id}/bid_submissions")
    rescue ApiClient::ApiError => e
      raise ForbiddenError, 'Bid submissions are not available yet' if e.status == 403 || e.status == 404

      raise ServiceError, "Failed to fetch bid submissions: #{e.message}"
    end
  end
end
