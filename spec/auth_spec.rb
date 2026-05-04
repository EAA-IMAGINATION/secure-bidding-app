require_relative 'spec_helper'

describe 'Auth Controller' do
  describe 'GET /auth/login' do
    it 'returns 200 OK' do
      get '/auth/login'
      _(last_response.status).must_equal 200
    end

    it 'displays login form' do
      get '/auth/login'
      _(last_response.body).must_include '<form'
      _(last_response.body).must_include 'email'
      _(last_response.body).must_include 'password'
    end

    it 'redirects to home if already authenticated' do
      set_login_session
      get '/auth/login'
      _(last_response.status).must_equal 302
      _(last_response.location).must_include '/'
    end
  end

  describe 'POST /auth/login' do
    it 'authenticates user with valid credentials' do
      stub_api_authenticate('user@example.com', 'password123',
        { 'id' => '1', 'email' => 'user@example.com' })

      post '/auth/login', email: 'user@example.com', password: 'password123'
      _(last_response.status).must_equal 302
      _(last_response.location).must_include '/'
    end

    it 'returns 401 on invalid credentials' do
      stub_api_authenticate('user@example.com', 'wrong',
        nil, error: true)

      post '/auth/login', email: 'user@example.com', password: 'wrong'
      _(last_response.status).must_equal 401
      _(last_response.body).must_include 'Invalid'
    end

    it 'stores account in session on successful login' do
      stub_api_authenticate('user@example.com', 'password123',
        { 'id' => '1', 'email' => 'user@example.com' })

      post '/auth/login', email: 'user@example.com', password: 'password123'
      follow_redirect!
      # Session should contain account info
      _(last_response.body).must_include 'Welcome'
    end

    it 'requires email parameter' do
      post '/auth/login', password: 'password123'
      _(last_response.status).must_equal 400
    end

    it 'requires password parameter' do
      post '/auth/login', email: 'user@example.com'
      _(last_response.status).must_equal 400
    end

    it 'displays flash error on failed login' do
      stub_api_authenticate('user@example.com', 'wrong',
        nil, error: true)

      post '/auth/login', email: 'user@example.com', password: 'wrong'
      _(last_response.body).must_include 'error'
    end
  end

  describe 'GET /auth/logout' do
    it 'clears session and redirects home' do
      set_login_session
      get '/auth/logout'
      _(last_response.status).must_equal 302
      _(last_response.location).must_include '/'
    end

    it 'displays flash notice on logout' do
      set_login_session
      get '/auth/logout'
      follow_redirect!
      _(last_response.body).must_include 'notice'
    end

    it 'removes account from session' do
      set_login_session
      get '/auth/logout'
      follow_redirect!
      _(last_response.body).must_include 'login'
    end
  end

  private

  def set_login_session
    account = {
      'id' => '123',
      'email' => 'test@example.com',
      'system_roles' => ['user']
    }
    set_cookie('rack.session', account.to_s)
  end

  def stub_api_authenticate(email, password, response, error: false)
    # Mock API client for authentication tests
    # Will be implemented when ApiClient is available
  end
end
