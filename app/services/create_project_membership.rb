# frozen_string_literal: true

module SecureBiddingApp
  # Service to create a project membership (invite or immediate assignment)
  class CreateProjectMembership
    class ValidationError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    # account_id: ID of the account to add
    # auth_token: optional bearer token (required for owner/admin actions)
    def call(project_id:, account_id:, auth_token: nil)
      headers = {}
      headers['Authorization'] = "Bearer #{auth_token}" if auth_token

      body = { 'account_id' => account_id, 'role' => 'project_owner' }

      @client.post("/projects/#{project_id}/memberships", body, headers: headers)
    rescue ApiClient::ApiError => e
      # Surface validation errors as ValidationError for controllers to handle
      if e.status == 400 || e.status == 422
        raise ValidationError, (e.body.is_a?(Hash) ? (e.body['error'] || e.body['message']).to_s : e.body.to_s)
      end

      raise
    end
  end
end
