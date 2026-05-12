# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'logger'
require 'rack/session'
require 'rack/request'

module SecureBiddingApp
  # Simple middleware to redirect HTTP to HTTPS and set HSTS headers
  class EnforceHttps
    def initialize(app)
      @app = app
    end

    def call(env)
      req = Rack::Request.new(env)
      # If request arrived via HTTP, redirect to HTTPS
      if req.scheme == 'http'
        url = req.url.sub(/^http:/, 'https:')
        return [301, { 'Location' => url, 'Content-Type' => 'text/html' }, ['Redirecting to HTTPS']]
      end

      status, headers, body = @app.call(env)
      headers['Strict-Transport-Security'] = 'max-age=63072000; includeSubDomains; preload'
      [status, headers, body]
    end
  end

  # Configuration for the Secure Bidding Web App
  class App < Roda
    plugin :environments

    # Environment variables setup
    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    # HTTP Request logging
    configure :development, :production do
      plugin :common_logger, $stdout
    end

    # Custom events logging
    LOGGER = Logger.new($stderr)
    def self.logger = LOGGER

    # Allows binding.pry in dev/test and rake console in production
    require 'pry'

    # Session signed and encrypted
    ONE_MONTH = 30 * 24 * 60 * 60

    configure :production do
      use EnforceHttps

      # Prefer Redis session store in production when REDIS_URL is provided
      # Prefer explicit environment variables over config file to support Heroku
      sess_secret = ENV['SESSION_SECRET'] && !ENV['SESSION_SECRET'].strip.empty? ? ENV['SESSION_SECRET'] : config.SESSION_SECRET

      if config.REDIS_URL && !config.REDIS_URL.to_s.strip.empty?
        require 'redis'
        require 'redis-rack'
        use Rack::Session::Redis, redis_server: config.REDIS_URL, expire_after: ONE_MONTH, secret: sess_secret
      else
        use Rack::Session::Cookie, expire_after: ONE_MONTH, secret: sess_secret
      end
    end

    configure :development, :test do
      # Use pooled sessions in development and test to approximate non-cookie store
      require 'rack/session/pool'
      use Rack::Session::Pool, expire_after: ONE_MONTH
      logger.level = Logger::ERROR
    end
  end
end
