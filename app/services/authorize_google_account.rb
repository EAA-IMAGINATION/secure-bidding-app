# frozen_string_literal: true

require 'http'
require 'json'

module SecureBiddingApp
  class AuthorizeGoogleAccount
    class UnauthorizedError < StandardError
      def message = 'Could not sign in with Google'
    end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config.API_URL)
    end

    def call(code)
      id_token = exchange_code_for_id_token(code)
      authorize_with_api(id_token)
    end

    private

    def exchange_code_for_id_token(code)
      response = HTTP.headers(accept: 'application/json')
        .post(google_token_url, form: token_params(code))
      raise UnauthorizedError unless response.status.success?

      JSON.parse(response.to_s).fetch('id_token')
    rescue KeyError, JSON::ParserError
      raise UnauthorizedError
    end

    def token_params(code)
      {
        client_id: @config.GOOGLE_CLIENT_ID,
        client_secret: @config.GOOGLE_CLIENT_SECRET,
        code: code,
        grant_type: 'authorization_code',
        redirect_uri: @config.GOOGLE_REDIRECT_URI
      }
    end

    def google_token_url
      value = @config.GOOGLE_TOKEN_URL.to_s.strip
      value.empty? ? App::GOOGLE_TOKEN_URL_DEFAULT : value
    end

    def authorize_with_api(id_token)
      response = @client.post('/auth/sso', SignedMessage.sign({ id_token: id_token }))
      account = response.reject { |key, _| key == 'token' }
      { account: account, auth_token: response['token'] }
    rescue ApiClient::ApiError
      raise UnauthorizedError
    end
  end
end
