# frozen_string_literal: true

require_relative 'spec_helper'
require 'json'
require 'webmock/minitest'

describe 'Admin users management' do
  let(:base_url) { SecureBiddingApp::App.config.API_URL.to_s.chomp('/') }
  let(:admin_id) { 'admin-123' }
  let(:token) { 'admin-session-token' }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  def stub_admin_profile
    stub_request(:get, "#{base_url}/accounts/#{admin_id}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          id: admin_id,
          username: 'admin-user',
          email: 'admin@example.com',
          system_role: 'admin',
          email_verified: true,
          capabilities: { can_manage_accounts: true, admin: true }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def login_as_admin
    stub_admin_profile
    stub_request(:post, "#{base_url}/auth/authenticate")
      .with { |req|
        body = JSON.parse(req.body)
        body.dig('data', 'username') == 'admin-user' && body.dig('data', 'password') == 'secret'
      }
      .to_return(
        status: 200,
        body: {
          id: admin_id,
          username: 'admin-user',
          email: 'admin@example.com',
          system_role: 'admin',
          email_verified: true,
          capabilities: { can_manage_accounts: true, admin: true },
          token: token
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post '/auth/login', username: 'admin-user', password: 'secret'
    _(last_response.status).must_equal 302
  end

  it 'shows Users in the nav for admins' do
    login_as_admin

    stub_request(:get, "#{base_url}/accounts")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: { accounts: [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    get '/admin/users'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'href="/admin/users"'
    _(last_response.body).must_include 'Users'
    _(last_response.body).wont_include 'Admin Users'
  end

  it 'redirects legacy create-user URL to the users list' do
    login_as_admin

    stub_request(:get, "#{base_url}/accounts")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: { accounts: [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    get '/admin/users/new'

    _(last_response.status).must_equal 302
    _(last_response.location).must_equal '/admin/users'
  end

  it 'lists users without registration or create-user controls' do
    login_as_admin

    stub_request(:get, "#{base_url}/accounts")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          accounts: [
            { id: 'u1', username: 'alice', email: 'alice@example.com', system_role: 'member',
              email_verified: true }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get '/admin/users'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Users'
    _(last_response.body).wont_include 'Create New User'
    _(last_response.body).wont_include 'Register (self-service)'
    _(last_response.body).wont_include 'Temporary password'
  end

  it 'promotes an existing account to admin via roles form' do
    login_as_admin
    target_id = 'member-456'

    stub_request(:get, "#{base_url}/accounts/#{target_id}")
      .to_return(
        status: 200,
        body: {
          id: target_id,
          username: 'member-user',
          email: 'member@example.com',
          system_role: 'member',
          system_roles: %w[bidder],
          email_verified: true
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:post, "#{base_url}/accounts/#{target_id}/system_roles")
      .with(
        body: { role: 'admin' }.to_json,
        headers: { 'Authorization' => "Bearer #{token}" }
      )
      .to_return(
        status: 201,
        body: { account_id: target_id, role: 'admin', status: 'assigned' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post "/admin/users/#{target_id}/roles", system_role: 'admin'

    _(last_response.status).must_equal 302
    _(last_response.location).must_equal "/admin/users/#{target_id}/roles"
  end
end
