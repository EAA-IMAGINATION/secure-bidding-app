# frozen_string_literal: true

module SecureBiddingApp
  class FetchAccountByUsername
    def initialize(config)
      @config = config
    end

    def call(username:, auth_token:, scope: nil)
      client = ApiClient.new(@config.API_URL, default_headers: { 'Authorization' => "Bearer #{auth_token}" })
      params = {}
      params['scope'] = scope if scope && !scope.to_s.strip.empty?
      res = client.get("/accounts/#{username}", params: params)
      Account.from_hash(res, auth_token)
    end
  end
end
