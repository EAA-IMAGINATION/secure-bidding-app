# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'logger'
require 'rack/session'

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
    use Rack::Session::Cookie,
        expire_after: ONE_MONTH,
        secret: config.SESSION_SECRET

    configure :development, :test do
      logger.level = Logger::ERROR
    end
  end
end
