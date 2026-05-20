# frozen_string_literal: true

module SecureBiddingApp
  # Encapsulates secure session state for the current account and registration flow.
  class CurrentSession
    def initialize(session, secure_session = SecureSession.new,
                   registration_token = RegistrationToken.new)
      @session = session
      @secure_session = secure_session
      @registration_token = registration_token
    end

    def current_account
      @secure_session.get(@session, :current_account)
    end

    def store_current_account(account)
      @secure_session.set(@session, :current_account, account)
    end

    def delete_current_account
      @secure_session.delete(@session, :current_account)
    end

    def pending_registration
      token = @secure_session.get(@session, :pending_registration)
      return nil unless token

      @registration_token.decode(token)
    rescue RegistrationToken::InvalidTokenError
      nil
    end

    def store_pending_registration(username:, email:)
      token = @registration_token.generate(username: username, email: email)
      @secure_session.set(@session, :pending_registration, token)
    end

    def delete_pending_registration
      @secure_session.delete(@session, :pending_registration)
    end
  end
end
