# frozen_string_literal: true

require_relative 'spec_helper'

describe 'App Controller' do
  describe 'GET /' do
    it 'returns 200 OK' do
      get '/'
      _(last_response.status).must_equal 200
    end

    it 'renders home page with welcome message' do
      get '/'
      _(last_response.body).must_include 'Welcome'
    end

    it 'includes navigation in response' do
      get '/'
      _(last_response.body).must_include 'nav'
    end

    it 'includes flash message container' do
      get '/'
      _(last_response.body).must_include 'flash'
    end
  end

  describe 'Unauthenticated user' do
    it 'shows login link' do
      get '/'
      _(last_response.body).must_include '/auth/login'
    end

    it 'does not show logout link' do
      get '/'
      _(last_response.body).wont_include '/auth/logout'
    end

    it 'does not show account link' do
      get '/'
      _(last_response.body).wont_include '/account'
    end
  end

  describe 'Routes respond' do
    it 'GET /auth/login returns 200' do
      get '/auth/login'
      _(last_response.status).must_equal 200
    end

    it 'GET /auth/login displays form' do
      get '/auth/login'
      _(last_response.body).must_include '<form'
    end

    it 'GET /auth/login has email field' do
      get '/auth/login'
      _(last_response.body).must_include 'username'
    end

    it 'GET /auth/login has password field' do
      get '/auth/login'
      _(last_response.body).must_include 'password'
    end

    it 'POST /api/v1/auth/authenticate returns 400 on missing credentials' do
      post '/api/v1/auth/authenticate', {}.to_json, { 'CONTENT_TYPE' => 'application/json' }
      _(last_response.status).must_equal 400
    end
  end
end

describe SecureBiddingApp::RoutingHelpers do
  class FakeRequest
    attr_reader :scheme, :url

    def initialize(scheme, url)
      @scheme = scheme
      @url = url
    end
  end

  class FakeRouting
    include SecureBiddingApp::RoutingHelpers

    attr_reader :request, :redirected_to

    def initialize(scheme, url)
      @request = FakeRequest.new(scheme, url)
    end

    def scheme
      request.scheme
    end

    def url
      request.url
    end

    def redirect(url)
      @redirected_to = url
    end
  end

  it 'redirects http requests to https' do
    routing = FakeRouting.new('http', 'http://example.test/path?x=1')

    routing.redirect_http_to_https

    _(routing.redirected_to).must_equal 'https://example.test/path?x=1'
  end

  it 'does not redirect https requests' do
    routing = FakeRouting.new('https', 'https://example.test/path')

    routing.redirect_http_to_https

    _(routing.redirected_to).must_be_nil
  end
end
