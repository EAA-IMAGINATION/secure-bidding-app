# frozen_string_literal: true

require 'json'
require 'roda'
require_relative 'app'

module SecureBiddingApp
  # Web controller for authentication
  class App < Roda
    route('auth') do |routing|
      @login_route = '/auth/login'

      routing.is 'login' do
        routing.get { view :login }
      end

      routing.is 'reset-password' do
        routing.get { view :reset_password }
        routing.post { handle_reset_password_post(routing) }
      end

      routing.is 'register' do
        routing.get { routing.redirect '/register' }
        routing.post { routing.redirect '/register' }
      end

      routing.on 'logout' do
        routing.get { handle_logout(routing) }
      end
    end

    route('api') do |routing|
      routing.on 'v1' do
        routing.on 'auth' do
          routing.is 'authenticate' do
            routing.post { handle_login_post(routing) }
          end
        end
      end
    end

    private

    def handle_login_post(routing)
      payload = login_payload(routing)
      username = payload['username'].to_s.strip
      password = payload['password'].to_s

      authenticate_and_redirect(routing, username, password)
    rescue AuthenticateAccount::UnauthorizedError => e
      handle_login_error(routing, e, 'Invalid username or password', 403)
    rescue JSON::ParserError => e
      handle_login_error(routing, e, 'Invalid JSON payload', 400)
    rescue StandardError => e
      handle_login_error(routing, e, 'An error occurred during login', 400)
    end

    def authenticate_and_redirect(routing, username, password)
      account = AuthenticateAccount.new(App.config).call(
        username: username, password: password
      )
      @current_session.store_current_account(account)
      return json_login_success(routing, account) if json_request?(routing)

      flash[:notice] = "Welcome back #{account['username']}!"
      routing.redirect '/'
    end

    def handle_login_error(routing, error, message = nil, status = 400)
      App.logger.warn "LOGIN FAILED: #{error.inspect}"
      if json_request?(routing)
        response.status = status
        return { error: message || 'Username and password did not match our records' }.to_json
      end

      flash.now[:error] = message || 'Username and password did not match our records'
      response.status = status
      view :login
    end

    def handle_reset_password_post(routing)
      email = routing.params['email'].to_s.strip
      password = routing.params['password'].to_s

      ResetAccountPassword.new(App.config).call(email: email, password: password)
      flash[:notice] = 'Password updated. You can log in with the new password.'
      routing.redirect '/auth/login'
    rescue ResetAccountPassword::ValidationError, ResetAccountPassword::NotFoundError => e
      flash.now[:error] = e.message
      response.status = 400
      view :reset_password
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Password reset failed')
      response.status = e.status.to_i
      view :reset_password
    end

    def handle_logout(routing)
      @current_session.delete_current_account
      flash[:notice] = "You've been logged out"
      routing.redirect @login_route
    end

    def api_error_message(error, fallback)
      return error.body['error'].to_s if error.body.is_a?(Hash) && error.body['error']
      return error.body['message'].to_s if error.body.is_a?(Hash) && error.body['message']

      fallback
    end

    def login_payload(routing)
      return JSON.parse(routing.body.read) if json_request?(routing)

      routing.params
    end

    def json_request?(routing)
      routing.env['CONTENT_TYPE'].to_s.start_with?('application/json')
    end

    def json_login_success(routing, account)
      response['Content-Type'] = 'application/json'
      response.status = 200
      {
        id: account['id'],
        username: account['username'],
        email: account['email'],
        system_role: account['system_role'],
        system_roles: account['system_roles'],
        redirect_to: '/'
      }.to_json
    end
  end
end
