# frozen_string_literal: true

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
    end

    it 'form has email input' do
      get '/auth/login'
      _(last_response.body).must_include 'type="email"'
    end

    it 'form has password input' do
      get '/auth/login'
      _(last_response.body).must_include 'type="password"'
    end

    it 'form has submit button' do
      get '/auth/login'
      _(last_response.body).must_include 'type="submit"'
    end
  end

  describe 'POST /auth/login with empty params' do
    it 'returns 400 on missing email' do
      post '/auth/login', password: 'password123'
      _(last_response.status).must_equal 400
    end

    it 'returns 400 on missing password' do
      post '/auth/login', email: 'user@example.com'
      _(last_response.status).must_equal 400
    end

    it 'returns 400 on empty request' do
      post '/auth/login', {}
      _(last_response.status).must_equal 400
    end
  end

  describe 'GET /auth/logout' do
    it 'redirects to home (302)' do
      get '/auth/logout'
      _(last_response.status).must_equal 302
    end

    it 'redirects to /' do
      get '/auth/logout'
      _(last_response.location).must_include '/'
    end
  end
end
