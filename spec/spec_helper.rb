# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'

# Load app
require_relative '../require_app'
require_app

# Make services available at top level for tests
ApiClient = SecureBiddingApp::ApiClient
AuthenticateAccount = SecureBiddingApp::AuthenticateAccount

module TestHelpers
  include Rack::Test::Methods

  def app
    @app ||= SecureBiddingApp::App
  end
end

Minitest::Spec.include TestHelpers
