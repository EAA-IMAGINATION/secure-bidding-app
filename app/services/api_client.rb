# frozen_string_literal: true

require 'http'
require 'json'
require 'uri'

module SecureBiddingApp
  # Shared helper for HTTP calls to the Secure Bidding API
  class ApiClient
    # Wraps a non-2xx API response with parsed body for the caller to inspect
    class ApiError < StandardError
      attr_reader :status, :body

      def initialize(status, body)
        @status = status
        @body = body
        super(body.is_a?(Hash) ? body['message'].to_s : body.to_s)
      end
    end

    def initialize(base_url)
      @base_url = base_url.to_s.chomp('/')
    end

    def get(path, params: {})
      full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
      parse(HTTP.get(url(full_path)))
    end

    def post(path, body)
      parse(HTTP.post(url(path), json: body))
    end

    def put(path, body)
      parse(HTTP.put(url(path), json: body))
    end

    def delete(path, body = nil)
      request = HTTP.headers('Content-Type' => 'application/json')
      response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
      parse(response)
    end

    private

    def url(path)
      path = "/#{path}" unless path.start_with?('/')
      "#{@base_url}#{path}"
    end

    def parse(response)
      raw = response.body.to_s
      parsed = raw.empty? ? {} : JSON.parse(raw)
      raise ApiError.new(response.code, parsed) unless (200..299).cover?(response.code)

      parsed
    end
  end
end
