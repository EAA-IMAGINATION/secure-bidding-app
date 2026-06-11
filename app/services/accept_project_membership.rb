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
      if [403, 404].include?(e.status.to_i)
        message = e.body.is_a?(Hash) ? (e.body['error'] || e.body['message']).to_s : e.body.to_s
        raise PermissionError, message.empty? ? 'No pending collaboration invite found' : message
      end

      raise
    end
  end
end
