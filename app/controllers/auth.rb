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

      routing.on 'logout' do
        routing.get { handle_logout(routing) }
      end
    end

    private

    def handle_login_post(routing)
      username = routing.params['username'].to_s.strip
      password = routing.params['password'].to_s
      authenticate_and_redirect(routing, username, password)
    rescue StandardError => e
      handle_login_error(e)
    end

    def authenticate_and_redirect(routing, username, password)
      account = AuthenticateAccount.new(App.config).call(
        username: username, password: password
      )
      session[:current_account] = account
      flash[:notice] = "Welcome back #{account['username']}!"
      routing.redirect '/'
    end

    def handle_login_error(error)
      App.logger.warn "LOGIN FAILED: #{error.inspect}"
      flash.now[:error] = 'Username and password did not match our records'
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
