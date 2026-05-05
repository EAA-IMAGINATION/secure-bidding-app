# frozen_string_literal: true

require 'roda'
require_relative 'app'

module SecureBiddingApp
  # Web controller for account management
  class App < Roda
    route('account') do |routing|
      routing.on String do |username|
        routing.get do
          require_login!(routing)
          
          # Only allow users to view their own account
          if @current_account['username'] != username
            response.status = 403
            flash.now[:error] = 'You do not have permission to view this account'
            view :login
          else
            view :account, locals: { current_account: @current_account }
          end
        end
      end
    end
  end
end
