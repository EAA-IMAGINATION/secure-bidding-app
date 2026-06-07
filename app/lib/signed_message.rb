# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module SecureBiddingApp
  # Signs outgoing API request bodies with the app's private Ed25519 SIGNING_KEY.
  class SignedMessage
    class KeypairError < StandardError; end

    def self.setup(signing_key64)
      @signing_key = Base64.strict_decode64(signing_key64)
    rescue StandardError
      raise KeypairError, 'Signing key not found'
    end

    def self.sign(message)
      signature = RbNaCl::SigningKey.new(@signing_key)
        .sign(message.to_json)
        .then { |sig| Base64.strict_encode64(sig) }

      { data: message, signature: signature }
    end
  end
end
