# frozen_string_literal: true

module SecureBiddingApp
  # Service to create a project membership (invite or immediate assignment)
  class CreateProjectMembership
    class ValidationError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    # username: invitee username (preferred)
    # account_id: legacy UUID lookup
    # auth_token: optional bearer token (required for owner/admin actions)
    def call(project_id:, username: nil, account_id: nil, auth_token: nil)
      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token

      body = { 'role' => 'project_owner' }
      normalized_username = username.to_s.strip
      normalized_account_id = account_id.to_s.strip

      if normalized_username.empty? && normalized_account_id.empty?
        raise ValidationError, 'Username is required'
      end

      if normalized_username.empty?
        body['account_id'] = normalized_account_id
      else
        body['username'] = normalized_username
      end

      @client.post("/projects/#{project_id}/memberships", body, headers: headers)
    rescue ApiClient::ApiError => e
      if e.status == 400 || e.status == 422
        raise ValidationError, (e.body.is_a?(Hash) ? (e.body['error'] || e.body['message']).to_s : e.body.to_s)
      end

      raise
    end
  end
end
