# frozen_string_literal: true

require 'base64'

module SecureBiddingApp
  # Helper to store encrypted session values using SecureMessaging
  class SecureSession
    def initialize(messenger = SecureMessaging.new)
      @messenger = messenger
    end

    def set(session, key, value)
      session[key] = @messenger.encrypt(Marshal.dump(value))
    end

    def get(session, key)
      token = session[key]
      return nil unless token
      begin
        Marshal.load(@messenger.decrypt(token))
      rescue StandardError
        nil
      end
    end

    def delete(session, key)
      session.delete(key)
    end
  end
end
