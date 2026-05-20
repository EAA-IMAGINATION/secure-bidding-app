# frozen_string_literal: true

require_relative 'spec_helper'
require 'webmock/minitest'
require 'ostruct'

describe 'Reset password flow' do
  let(:base_url) { 'http://localhost:3000/api/v1' }
  let(:config) { OpenStruct.new(API_URL: base_url) }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  describe ResetAccountPassword do
    it 'finds the account and updates its password' do
      stub_request(:get, "#{base_url}/accounts/search")
        .with(query: hash_including(email: 'admin@example.com'))
        .to_return(status: 200, body: '{"accounts":[{"id":"abc","username":"admin","email":"admin@example.com"}]}',
                   headers: { 'Content-Type' => 'application/json' })

      stub_request(:patch, "#{base_url}/accounts/abc")
        .with(body: hash_including(password: 'new-secret'))
        .to_return(status: 200, body: '{"id":"abc","status":"updated"}',
                   headers: { 'Content-Type' => 'application/json' })

      result = ResetAccountPassword.new(config).call(email: 'admin@example.com',
                                                     password: 'new-secret')

      _(result['id']).must_equal 'abc'
      _(result['username']).must_equal 'admin'
    end
  end

  describe 'GET /auth/reset-password' do
    it 'renders the reset form' do
      get '/auth/reset-password'

      _(last_response.status).must_equal 200
      _(last_response.body).must_include 'Reset password'
      _(last_response.body).must_include 'Back to login'
    end
  end

  describe 'POST /auth/reset-password' do
    it 'updates the password and redirects to login' do
      stub_request(:get, "#{base_url}/accounts/search")
        .with(query: hash_including(email: 'admin@example.com'))
        .to_return(status: 200, body: '{"accounts":[{"id":"abc","username":"admin","email":"admin@example.com"}]}',
                   headers: { 'Content-Type' => 'application/json' })

      stub_request(:patch, "#{base_url}/accounts/abc")
        .with(body: hash_including(password: 'new-secret'))
        .to_return(status: 200, body: '{"id":"abc","status":"updated"}',
                   headers: { 'Content-Type' => 'application/json' })

      post '/auth/reset-password', email: 'admin@example.com', password: 'new-secret'

      _(last_response.status).must_equal 302
      _(last_response.location).must_include '/auth/login'
    end
  end
end
