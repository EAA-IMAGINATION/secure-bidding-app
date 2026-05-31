# frozen_string_literal: true

module SecureBiddingApp
  class FetchAccountByUsername
    def initialize(config)
      @config = config
    end

    def call(username:, auth_token:)
      client = ApiClient.new(@config.API_URL, default_headers: { 'Authorization' => "Bearer #{auth_token}" })
      res = client.get("/accounts/#{username}")
      Account.from_hash(res, auth_token)
    end
  end
end
