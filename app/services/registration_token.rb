# frozen_string_literal: true

require 'json'

module SecureBiddingApp
  # Encrypts and decrypts pending registration payloads for session storage.
  class RegistrationToken
    class InvalidTokenError < StandardError; end

    def initialize(messenger = SecureMessaging.new)
      @messenger = messenger
    end

    def generate(username:, email:)
      @messenger.encrypt({ 'username' => username, 'email' => email }.to_json)
    end

    def decode(token)
      JSON.parse(@messenger.decrypt(token))
    rescue StandardError => e
      raise InvalidTokenError, e.message
    end
  end
end
