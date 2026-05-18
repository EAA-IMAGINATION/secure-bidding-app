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

    def initialize(base_url, default_headers: {})
      @base_url = base_url.to_s.chomp('/')
      @default_headers = default_headers
    end

    def get(path, params: {}, headers: {})
      full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
      parse(request(headers).get(url(full_path)))
    end

    def post(path, body, headers: {})
      parse(request(headers).post(url(path), json: body))
    end

    def put(path, body, headers: {})
      parse(request(headers).put(url(path), json: body))
    end

    def patch(path, body, headers: {})
      parse(request(headers).patch(url(path), json: body))
    end

    def delete(path, body = nil, headers: {})
      response = body ? request(headers).delete(url(path), body: body.to_json) : request(headers).delete(url(path))
      parse(response)
    end

    private

    def request(headers)
      merged_headers = @default_headers.merge(headers)
      return HTTP if merged_headers.empty?

      HTTP.headers(merged_headers)
    end

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
