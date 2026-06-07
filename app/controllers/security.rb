# frozen_string_literal: true

require 'roda'
require 'secure_headers'
require 'uri'
require_relative 'app'

module SecureBiddingApp
  # Browser security headers, CSP, HTTPS enforcement, and violation reporting.
  class App < Roda
    plugin :environments
    plugin :multi_route

    SCRIPT_SRC = %w[https://cdn.jsdelivr.net].freeze
    STYLE_SRC = %w[https://bootswatch.com https://cdn.jsdelivr.net].freeze
    IMG_SRC = %w[https://*.googleusercontent.com data:].freeze

    use SecureHeaders::Middleware

    class EnforceHttps
      def initialize(app)
        @app = app
      end

      def call(env)
        req = Rack::Request.new(env)
        if req.scheme == 'http'
          url = req.url.sub(/^http:/, 'https:')
          return [301, { 'Location' => url, 'Content-Type' => 'text/html' }, ['Redirecting to HTTPS']]
        end

        status, headers, body = @app.call(env)
        headers['Strict-Transport-Security'] = 'max-age=63072000; includeSubDomains; preload'
        [status, headers, body]
      end
    end

    configure :production do
      use EnforceHttps
    end

    configure do
      api_origin = begin
        URI.parse(config.API_URL.to_s).origin
      rescue URI::InvalidURIError
        nil
      end
      connect_src = %w['self']
      connect_src << api_origin if api_origin

      cookie_config = {
        httponly: true,
        samesite: { lax: true }
      }
      cookie_config[:secure] = true if environment == :production

      SecureHeaders::Configuration.default do |headers|
        headers.cookies = cookie_config

        headers.x_frame_options = 'DENY'
        headers.x_content_type_options = 'nosniff'
        headers.x_xss_protection = '1'
        headers.x_permitted_cross_domain_policies = 'none'
        headers.referrer_policy = 'origin-when-cross-origin'

        headers.csp = {
          report_only: false,
          preserve_schemes: true,
          default_src: %w['self'],
          child_src: %w['self'],
          connect_src: connect_src,
          img_src: %w['self'] + IMG_SRC,
          font_src: %w['self'],
          script_src: %w['self'] + SCRIPT_SRC,
          style_src: %w['self'] + STYLE_SRC,
          form_action: %w['self'],
          frame_ancestors: %w['none'],
          object_src: %w['none'],
          report_uri: %w[/security/report_csp_violation]
        }
      end
    end

    route('security') do |routing|
      routing.post 'report_csp_violation' do
        App.logger.warn "CSP VIOLATION: #{request.body.read}"
        response.status = 204
        nil
      end
    end
  end
end
