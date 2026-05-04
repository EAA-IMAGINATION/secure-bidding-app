require_relative 'spec_helper'

describe 'App Controller' do
  describe 'GET /' do
    it 'returns 200 OK' do
      get '/'
      _(last_response.status).must_equal 200
    end

    it 'renders home page' do
      get '/'
      _(last_response.body).must_include 'Welcome'
    end

    it 'shows login link when not authenticated' do
      get '/'
      _(last_response.body).must_include '/auth/login'
    end

    it 'shows logout link when authenticated' do
      set_login_session
      get '/'
      _(last_response.body).must_include '/auth/logout'
    end

    it 'hides login link when authenticated' do
      set_login_session
      get '/'
      _(last_response.body).wont_include '/auth/login'
    end
  end

  describe 'Navigation bar' do
    it 'displays navigation' do
      get '/'
      _(last_response.body).must_include '<nav'
    end

    it 'includes home link' do
      get '/'
      _(last_response.body).must_include 'href="/"'
    end

    it 'shows role badge for authenticated users' do
      set_login_session(roles: ['admin'])
      get '/'
      _(last_response.body).must_include 'admin'
    end
  end

  describe 'Flash messages' do
    it 'displays flash messages in layout' do
      get '/'
      _(last_response.body).must_include 'flash'
    end
  end

  private

  def set_login_session(roles: ['user'])
    account = {
      'id' => '123',
      'email' => 'test@example.com',
      'system_roles' => roles
    }
    set_cookie('rack.session', account.to_s)
  end
end
