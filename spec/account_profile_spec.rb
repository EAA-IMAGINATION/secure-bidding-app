# frozen_string_literal: true

require_relative 'spec_helper'
require 'json'
require 'webmock/minitest'

describe 'Account profile flow' do
  let(:base_url) { SecureBiddingApp::App.config.API_URL.to_s.chomp('/') }
  let(:account_id) { 'acc-123' }
  let(:token) { 'session-token-123' }
  let(:account_username) { 'demo-user' }
  let(:account_email) { 'demo@example.com' }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  def login_as(username: account_username, password: 'current-pass', email: account_email, email_verified: true)
    stub_request(:post, "#{base_url}/auth/authenticate")
      .with(body: hash_including(username: username, password: password))
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: username,
          email: email,
          email_verified: email_verified,
          token: token
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post '/auth/login', username: username, password: password
    _(last_response.status).must_equal 302
  end

  def stub_profile_get(username: account_username, email: account_email, email_verified: true)
    stub_request(:get, "#{base_url}/accounts/#{account_id}")
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: username,
          email: email,
          email_verified: email_verified,
          system_roles: %w[bidder]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_published_projects
    stub_request(:get, "#{base_url}/projects")
      .to_return(
        status: 200,
        body: { projects: [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'shows the profile verification state and edit entry points' do
    login_as
    stub_profile_get

    get '/account/demo-user'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Verified'
    _(last_response.body).must_include 'Edit profile'
    _(last_response.body).wont_include 'Resend verification'
  end

  it 'hides the verification banner when the session is stale but the API says verified' do
    login_as(email_verified: false)
    stub_profile_get(email_verified: true)
    stub_published_projects

    get '/'

    _(last_response.status).must_equal 200
    _(last_response.body).wont_include 'Verify your email to unlock bidding and project management.'
  end

  it 'hides the verification banner for admin accounts even when email_verified is missing from session' do
    stub_request(:post, "#{base_url}/auth/authenticate")
      .with(body: hash_including(username: account_username, password: 'current-pass'))
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: account_username,
          email: account_email,
          system_role: 'admin',
          system_roles: [],
          token: token
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post '/auth/login', username: account_username, password: 'current-pass'
    _(last_response.status).must_equal 302
    stub_profile_get(email_verified: true)
    stub_published_projects

    get '/'

    _(last_response.status).must_equal 200
    _(last_response.body).wont_include 'Verify your email to unlock bidding and project management.'
  end

  it 'redirects home without the banner after resend when the account is already verified' do
    login_as(email_verified: false)
    stub_profile_get(email_verified: true)
    stub_published_projects

    post '/account/demo-user/resend_verification'

    _(last_response.status).must_equal 302
    follow_redirect!

    _(last_response.status).must_equal 200
    _(last_response.body).wont_include 'Verify your email to unlock bidding and project management.'
    _(last_response.body).must_include 'Your email is already verified'
  end

  it 'shows an inline resend button beside the unverified badge on the profile page' do
    login_as(email_verified: false)
    stub_profile_get(email_verified: false)

    get '/account/demo-user'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Unverified'
    _(last_response.body).must_include 'Send verification email'
  end

  it 'clears the banner after confirming email verification from the link while logged in' do
    login_as(email_verified: false)
    stub_profile_get(email_verified: false)
    stub_published_projects

    stub_request(:post, "#{base_url}/auth/verification-preview")
      .with(body: hash_including('registration_token' => 'verify-token'))
      .to_return(
        status: 200,
        body: {
          purpose: 'email_verification',
          username: account_username,
          email: account_email
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get '/verify-email?token=verify-token'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Confirm email address'

    stub_request(:post, "#{base_url}/auth/verify")
      .with(body: hash_including('registration_token' => 'verify-token'))
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: account_username,
          email: account_email,
          email_verified: true,
          status: 'verified'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post '/verify-email', registration_token: 'verify-token', verification_purpose: 'email_verification'

    _(last_response.status).must_equal 302
    stub_profile_get(email_verified: true)
    follow_redirect!

    _(last_response.status).must_equal 200
    _(last_response.body).wont_include 'Verify your email to unlock bidding and project management.'
    _(last_response.body).must_include 'Your email has been verified'
  end

  it 'renders the edit form' do
    login_as
    stub_profile_get

    get '/account/demo-user/edit'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Edit profile'
    _(last_response.body).must_include 'Current password'
    _(last_response.body).must_include 'New password'
  end

  it 'rejects invalid profile input with a 400 response' do
    login_as
    stub_profile_get

    patch '/account/demo-user/edit',
          username: account_username,
          email: account_email,
          password: 'new-password-123',
          password_confirm: 'different-password',
          current_password: 'current-pass'

    _(last_response.status).must_equal 400
    _(last_response.body).must_include 'must match password'
  end

  it 'updates the profile, marks the email as unverified, and shows the verification notice' do
    login_as
    stub_request(:get, "#{base_url}/accounts/#{account_id}")
      .to_return(
        {
          status: 200,
          body: {
            id: account_id,
            username: account_username,
            email: account_email,
            email_verified: true,
            system_roles: %w[bidder]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        },
        {
          status: 200,
          body: {
            id: account_id,
            username: account_username,
            email: 'new@example.com',
            email_verified: false,
            system_roles: %w[bidder]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        }
      )

    stub_request(:patch, "#{base_url}/accounts/#{account_id}")
      .with(
        headers: hash_including('Authorization' => "Bearer #{token}"),
        body: hash_including(
          username: account_username,
          email: 'new@example.com',
          password: 'new-password-123'
        )
      )
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: account_username,
          email: 'new@example.com',
          email_verified: false
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    patch '/account/demo-user/edit',
          username: account_username,
          email: 'new@example.com',
          password: 'new-password-123',
          password_confirm: 'new-password-123',
          current_password: 'current-pass'

    _(last_response.status).must_equal 302
    follow_redirect!

    _(last_response.body).must_include 'Verification email sent'
    _(last_response.body).must_include 'Unverified'
  end

  it 'rejects a bad current password' do
    login_as
    stub_profile_get

    stub_request(:post, "#{base_url}/auth/authenticate")
      .with(body: hash_including(username: account_username, password: 'wrong-pass'))
      .to_return(status: 401, body: { error: 'Invalid credentials' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    patch '/account/demo-user/edit',
          username: account_username,
          email: account_email,
          password: 'new-password-123',
          password_confirm: 'new-password-123',
          current_password: 'wrong-pass'

    _(last_response.status).must_equal 403
    _(last_response.body).must_include 'Current password is incorrect'
  end

  it 'handles API validation failures from the update endpoint' do
    login_as
    stub_profile_get

    stub_request(:patch, "#{base_url}/accounts/#{account_id}")
      .to_return(status: 422, body: { error: 'email already exists' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    patch '/account/demo-user/edit',
          username: account_username,
          email: 'taken@example.com',
          password_confirm: '',
          current_password: ''

    _(last_response.status).must_equal 422
    _(last_response.body).must_include 'email already exists'
  end

  it 'resends verification email from the profile page' do
    login_as(email_verified: false)
    stub_profile_get(email_verified: false)

    stub_request(:post, "#{base_url}/accounts/#{account_id}/resend_verification")
      .with(headers: hash_including('Authorization' => "Bearer #{token}"))
      .to_return(
        status: 200,
        body: { status: 'sent' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post '/account/demo-user/resend_verification'

    _(last_response.status).must_equal 302
    follow_redirect!
    _(last_response.body).must_include 'Verification email sent — open the link in your inbox'
  end
end
