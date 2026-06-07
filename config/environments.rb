# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'logger'
require 'rack/session'
require 'rack/request'
require_relative '../app/lib/signed_message'

module SecureBiddingApp
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

    DEFAULT_SIGNING_KEY = 'Q1QC/DUM0/UOmjYimkowLRDCkd+cvWXCeRfjOuUB8No='

    configure do
      signing_key = ENV['SIGNING_KEY'].to_s
      signing_key = config.SIGNING_KEY.to_s if signing_key.empty? && config.respond_to?(:SIGNING_KEY)
      if signing_key.empty? && %i[development test].include?(environment)
        signing_key = DEFAULT_SIGNING_KEY
      end
      if signing_key.empty? && environment == :production
        raise KeyError, 'SIGNING_KEY must be configured in production'
      end

      SecureBiddingApp::SignedMessage.setup(signing_key) unless signing_key.empty?
    end

    configure :production do
      # Prefer Redis session store in production when a Redis URL is provided
      # Prefer explicit environment variables over config file to support Heroku
      env_secret = ENV.fetch('SESSION_SECRET', nil)
      sess_secret = if env_secret && !env_secret.strip.empty?
                      env_secret
                    else
                      config.SESSION_SECRET
                    end
      if sess_secret.to_s.bytesize < 64
        raise ArgumentError,
              'SESSION_SECRET must be at least 64 bytes; ' \
              'run bundle exec rake generate:session_secret'
      end

      redis_url = if config.REDIS_URL && !config.REDIS_URL.to_s.strip.empty?
                    config.REDIS_URL
                  elsif config.REDISCLOUD_URL && !config.REDISCLOUD_URL.to_s.strip.empty?
                    config.REDISCLOUD_URL
                  end

      if redis_url
        require 'redis'
        require 'redis-rack'
        use Rack::Session::Redis, redis_server: redis_url, expire_after: ONE_MONTH,
                                  secret: sess_secret,
                                  same_site: :lax,
                                  httponly: true,
                                  secure: true
      else
        use Rack::Session::Cookie, expire_after: ONE_MONTH, secret: sess_secret,
                                   same_site: :lax, httponly: true, secure: true
      end
    end

    configure :development, :test do
      ENV['API_URL'] ||= 'http://localhost:3000/api/v1'
      ENV['APP_URL'] ||= 'http://localhost:9292'

      # Use pooled sessions in development and test to approximate non-cookie store
      require 'rack/session/pool'
      use Rack::Session::Pool, expire_after: ONE_MONTH,
                               same_site: :lax, httponly: true
      logger.level = Logger::ERROR
    end
  end
end
