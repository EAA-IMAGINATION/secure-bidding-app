# frozen_string_literal: true

require 'roda'
require_relative 'app'

module SecureBiddingApp
  # Web controller for authentication
  class App < Roda
    route('auth') do |routing|
      @login_route = '/auth/login'

      routing.is 'login' do
        routing.get { view :login }
        routing.post { handle_login_post(routing) }
      end

      routing.is 'register' do
        routing.get { view :register }
        routing.post { handle_register_post(routing) }
      end

      routing.on 'logout' do
        routing.get { handle_logout(routing) }
      end
    end

    private

    def handle_login_post(routing)
      username = routing.params['username'].to_s.strip
      password = routing.params['password'].to_s
      authenticate_and_redirect(routing, username, password)
    rescue AuthenticateAccount::UnauthorizedError => e
      handle_login_error(e, 'Invalid username or password')
    rescue StandardError => e
      handle_login_error(e, 'An error occurred during login')
    end

    def handle_register_post(routing)
      email = routing.params['email'].to_s.strip
      username = routing.params['username'].to_s.strip
      password = routing.params['password'].to_s

      account = CreateAccount.new(App.config).call(
        email: email, username: username, password: password
      )

      session[:current_account] = account
      flash[:notice] = "Welcome, #{account['username']}!"
      routing.redirect '/'
    rescue CreateAccount::ValidationError => e
      App.logger.warn "REGISTER FAILED: #{e.message}"
      flash.now[:error] = e.message
      response.status = 400
      view :register
    rescue ApiClient::ApiError => e
      App.logger.warn "REGISTER FAILED: #{e.inspect}"
      flash.now[:error] = e.body.is_a?(Hash) ? e.body['message'].to_s : 'Registration failed'
      response.status = 400
      view :register
    rescue StandardError => e
      App.logger.warn "REGISTER ERROR: #{e.inspect}"
      flash.now[:error] = 'An unexpected error occurred'
      response.status = 500
      view :register
    end

    def authenticate_and_redirect(routing, username, password)
      account = AuthenticateAccount.new(App.config).call(
        username: username, password: password
      )
      session[:current_account] = account
      flash[:notice] = "Welcome back #{account['username']}!"
      routing.redirect '/'
    end

    def handle_login_error(error, message = nil)
      App.logger.warn "LOGIN FAILED: #{error.inspect}"
      flash.now[:error] = message || 'Username and password did not match our records'
      response.status = 400
      view :login
    end

    def handle_logout(routing)
      session[:current_account] = nil
      flash[:notice] = "You've been logged out"
      routing.redirect @login_route
    end
  end
end
