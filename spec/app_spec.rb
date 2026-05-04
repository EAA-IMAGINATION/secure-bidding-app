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
      _(last_response.body).must_include 'email'
    end

    it 'GET /auth/login has password field' do
      get '/auth/login'
      _(last_response.body).must_include 'password'
    end
  end
end
