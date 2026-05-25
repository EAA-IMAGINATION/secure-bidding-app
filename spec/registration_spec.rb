# frozen_string_literal: true

require_relative 'spec_helper'
require 'webmock/minitest'
require 'ostruct'

describe 'Week 12 Registration Flow' do
  let(:base_url) { 'http://localhost:3001/api/v1' }
  let(:config) { OpenStruct.new(API_URL: base_url) }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  describe RegistrationToken do
    it 'round trips pending registration data' do
      token = RegistrationToken.new.generate(username: 'alice', email: 'alice@example.com')
      payload = RegistrationToken.new.decode(token)

      _(payload['username']).must_equal 'alice'
      _(payload['email']).must_equal 'alice@example.com'
    end
  end

  describe CurrentSession do
    it 'stores and restores pending registration data' do
      session = {}
      current_session = CurrentSession.new(session)

      current_session.store_pending_registration(username: 'alice', email: 'alice@example.com')

      _(current_session.pending_registration['username']).must_equal 'alice'
      _(current_session.pending_registration['email']).must_equal 'alice@example.com'
    end
  end

  describe InitiateRegistration do
    it 'checks availability and starts registration' do
      stub_request(:post, "#{base_url}/auth/availability")
        .to_return(status: 200, body: '{"available":{"username":true,"email":true}}',
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, "#{base_url}/auth/register")
        .to_return(status: 200, body: '{"message":"Check your email to verify your account"}',
                   headers: { 'Content-Type' => 'application/json' })

      result = InitiateRegistration.new(config).call(username: 'alice', email: 'alice@example.com')

      _(result['message']).must_include 'Check your email'
    end
  end

  describe VerifyRegistration do
    it 'posts the verification token to the API' do
      stub_request(:post, "#{base_url}/auth/verify")
        .to_return(status: 200, body: '{"token":"jwt","account":{"id":"1","username":"alice","email":"alice@example.com"}}',
                   headers: { 'Content-Type' => 'application/json' })

      result = VerifyRegistration.new(config).call(registration_token: 'token-value',
                                                   password: 'secret')

      _(result['token']).must_equal 'jwt'
      _(result['account']['username']).must_equal 'alice'
      _(result['account']['email']).must_equal 'alice@example.com'
    end
  end

  describe 'GET /register' do
    it 'renders the onboarding form' do
      get '/register'

      _(last_response.status).must_equal 200
      _(last_response.body).must_include 'Username'
      _(last_response.body).must_include 'Email'
      _(last_response.body).must_include "#{base_url}/auth/register"
      _(last_response.body).wont_include 'action="/register"'
    end
  end

  describe 'GET /register/verify/:token' do
    it 'renders the verification form' do
      token = RegistrationToken.new.generate(username: 'alice', email: 'alice@example.com')
      get "/register/verify/#{token}"

      _(last_response.status).must_equal 200
      _(last_response.body).must_include 'Verify your registration'
      _(last_response.body).must_include 'Password'
      _(last_response.body).must_include 'alice'
      _(last_response.body).must_include 'alice@example.com'
      _(last_response.body).must_include 'Confirm password'
    end
  end
end
