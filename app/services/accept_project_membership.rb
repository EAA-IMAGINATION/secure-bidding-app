# frozen_string_literal: true

module SecureBiddingApp
  # Service to accept a pending project membership invite
  class AcceptProjectMembership
    class PermissionError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(project_id:, auth_token:)
      raise PermissionError, 'Authentication required' if auth_token.to_s.strip.empty?

      headers = { 'Authorization' => "Bearer #{auth_token}" }
      @client.post("/projects/#{project_id}/memberships/accept", {}, headers: headers)
    rescue ApiClient::ApiError => e
      raise PermissionError, (e.body.is_a?(Hash) ? (e.body['error'] || e.body['message']).to_s : e.body.to_s) if e.status == 403

      raise
    end
  end
end
