# frozen_string_literal: true

require 'roda'
require_relative 'app'

module SecureBiddingApp
  # Web controller for authentication
  class App < Roda
    route('auth') do |routing|
      @login_route = '/auth/login'

      routing.is 'login' do
        # GET /auth/login
        routing.get do
          view :login
        end

        # POST /auth/login
        routing.post do
          username = routing.params['username'].to_s.strip
          password = routing.params['password'].to_s

          account = AuthenticateAccount.new(App.config).call(
            username: username, password: password
          )

          session[:current_account] = account
          flash[:notice] = "Welcome back #{account['username']}!"
          routing.redirect '/'
        rescue StandardError => e
          App.logger.warn "LOGIN FAILED: #{e.inspect}"
          flash.now[:error] = 'Username and password did not match our records'
          response.status = 400
          view :login
        end
      end

      routing.on 'logout' do
        # GET /auth/logout
        routing.get do
          session[:current_account] = nil
          flash[:notice] = "You've been logged out"
          routing.redirect @login_route
        end
      end
    end
  end
end
