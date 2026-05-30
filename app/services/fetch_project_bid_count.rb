# frozen_string_literal: true

module SecureBiddingApp
  class FetchProjectBidCount
    class ServiceError < StandardError; end

    def initialize(config)
      @config = config
    end

    def call(project_id, auth_token:)
      headers = { 'Authorization' => "Bearer #{auth_token}" }
      client = ApiClient.new(@config.API_URL, default_headers: headers)
      client.get("/projects/#{project_id}/bid_count")
    rescue ApiClient::ApiError => e
      raise ServiceError, "Failed to fetch bid count: #{e.message}" if e.status != 404

      { 'bid_count' => nil }
    end
  end
end
