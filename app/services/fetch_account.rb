# frozen_string_literal: true

module SecureBiddingApp
  # Fetch a single account record from the API.
  class FetchAccount
    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(user_id:, auth_token: nil)
      client = client_with_auth(auth_token)
      res = client.get("/accounts/#{user_id}")
      Account.from_hash(res, auth_token)
    end

    private

    def client_with_auth(auth_token)
      return @client if auth_token.to_s.strip.empty?

      ApiClient.new(@config.API_URL, default_headers: { 'Authorization' => "Bearer #{auth_token}" })
    end
  end
end
