ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'

# Load app
require_relative '../require_app'

include Rack::Test::Methods

def app
  @app ||= Roda.app
end
