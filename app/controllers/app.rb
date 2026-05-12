# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'

module SecureBiddingApp
  module RoutingHelpers
    def redirect_http_to_https
      return unless scheme == 'http'

      redirect url.sub(/^http:/, 'https:')
    end
  end

  # Base class for the Secure Bidding Web App
  class App < Roda
    use Rack::MethodOverride

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      routing.extend(RoutingHelpers)
      routing.redirect_http_to_https if App.environment == :production

      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = SecureSession.new.get(session, :current_account)

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        view 'home', locals: { current_account: @current_account }
      end
    end

    # Routes for account management
    route('account') do |routing|
      routing.on String do |username|
        routing.get do
          require_login!(routing)

          # Only allow users to view their own account
          if @current_account['username'] == username
            view :account, locals: { current_account: @current_account }
          else
            response.status = 403
            flash.now[:error] = 'You do not have permission to view this account'
            view :login
          end
        end
      end
    end

    private

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end

    def system_roles_of(current_account)
      current_account&.dig('system_roles') || []
    end

    def admin?(current_account)
      system_roles_of(current_account).include?('admin')
    end
  end
end
