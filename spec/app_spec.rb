# frozen_string_literal: true

require_relative 'spec_helper'

describe 'App Controller' do
  describe 'GET /' do
    before do
      # Mock FetchProjects to avoid API calls
      FetchProjects = SecureBiddingApp::FetchProjects
      @original_fetch_projects = FetchProjects
    end

    after do
      # Restore original
    end

    it 'returns 200 OK' do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(status: 200, body: { projects: [] }.to_json)

      get '/'
      _(last_response.status).must_equal 200
    end

    it 'renders home page with welcome message' do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(status: 200, body: { projects: [] }.to_json)

      get '/'
      _(last_response.body).must_include 'Welcome'
    end

    it 'lists only policy-available projects on the home catalog' do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(
          status: 200,
          body: {
            projects: [
              {
                id: 'open-project',
                title: 'Open Bids',
                budget_cents: 50_000,
                state: 'published',
                policy: { available_for_bidding: true }
              },
              {
                id: 'closed-project',
                title: 'Closed Bids',
                budget_cents: 50_000,
                state: 'published',
                policy: { available_for_bidding: false }
              }
            ]
          }.to_json
        )

      get '/'

      _(last_response.body).must_include 'Open Bids'
      _(last_response.body).wont_include 'Closed Bids'
    end

    it 'includes navigation in response' do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(status: 200, body: { projects: [] }.to_json)

      get '/'
      _(last_response.body).must_include 'nav'
    end

    it 'includes flash message container' do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(status: 200, body: { projects: [] }.to_json)

      get '/'
      _(last_response.body).must_include 'flash'
    end
  end

  describe 'Unauthenticated user' do
    before do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(status: 200, body: { projects: [] }.to_json)
    end

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

  describe 'Project routes' do
    before do
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/projects")
        .to_return(status: 200, body: { projects: [] }.to_json)
    end

    it 'GET /projects/new requires login' do
      get '/projects/new'
      _(last_response.status).must_equal 302
      _(last_response.location).must_include '/auth/login'
    end

    it 'GET /projects/new uses structured required document controls without crypto implementation banners' do
      account_id = '550e8400-e29b-41d4-a716-446655440001'
      token = 'member-token'
      session = {}
      CurrentSession.new(session).store_current_account(
        'id' => account_id,
        'username' => 'verified-member',
        'token' => token,
        'email_verified' => true,
        'system_role' => 'member'
      )
      stub_request(:get, "#{SecureBiddingApp::App.config.API_URL}/accounts/#{account_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(
          status: 200,
          body: {
            id: account_id,
            username: 'verified-member',
            token: token,
            email_verified: true,
            system_role: 'member'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      get '/projects/new', {}, 'rack.session' => session

      _(last_response.status).must_equal 200
      _(last_response.body).must_include 'data-required-documents-builder'
      _(last_response.body).must_include 'data-add-required-document'
      _(last_response.body).wont_include 'NaCl'
      _(last_response.body).wont_include 'keypair generated'
      _(last_response.body).wont_include 'crypto-status'
    end

    it 'GET /auth/login is accessible' do
      get '/auth/login'
      _(last_response.status).must_equal 200
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

    def redirect(new_url)
      new_url
    end
  end

  extend SecureBiddingApp::RoutingHelpers

  it 'does not redirect https' do
    req = FakeRequest.new('https', 'https://example.com/path')
    _(req.extend(SecureBiddingApp::RoutingHelpers).redirect_http_to_https).must_be_nil
  end

  it 'redirects http to https' do
    req = FakeRequest.new('http', 'http://example.com/path')
    _(req.extend(SecureBiddingApp::RoutingHelpers).redirect_http_to_https).must_equal 'https://example.com/path'
  end

  class CanonicalHostRequest
    attr_reader :host, :path, :query_string

    def initialize(host, path, query_string = '')
      @host = host
      @path = path
      @query_string = query_string
    end

    def redirect(url)
      url
    end
  end

  it 'redirects bare domain to canonical host from APP_URL in production' do
    req = CanonicalHostRequest.new('freelanceprocurementhub.tech', '/auth/sso')
    helper = req.extend(SecureBiddingApp::RoutingHelpers)
    def helper.production_host_redirect?
      true
    end

    def helper.canonical_app_host
      'www.freelanceprocurementhub.tech'
    end

    _(helper.redirect_to_canonical_host).must_equal 'https://www.freelanceprocurementhub.tech/auth/sso'
  end

  it 'preserves query string when redirecting to canonical host' do
    req = CanonicalHostRequest.new('freelanceprocurementhub.tech', '/auth/sso_callback', 'state=abc&code=xyz')
    helper = req.extend(SecureBiddingApp::RoutingHelpers)
    def helper.production_host_redirect?
      true
    end

    def helper.canonical_app_host
      'www.freelanceprocurementhub.tech'
    end

    target = helper.redirect_to_canonical_host
    _(target).must_equal 'https://www.freelanceprocurementhub.tech/auth/sso_callback?state=abc&code=xyz'
  end

  it 'does not redirect when already on canonical host' do
    req = CanonicalHostRequest.new('www.freelanceprocurementhub.tech', '/auth/login')
    helper = req.extend(SecureBiddingApp::RoutingHelpers)
    def helper.production_host_redirect?
      true
    end

    def helper.canonical_app_host
      'www.freelanceprocurementhub.tech'
    end

    _(helper.redirect_to_canonical_host).must_be_nil
  end
end
