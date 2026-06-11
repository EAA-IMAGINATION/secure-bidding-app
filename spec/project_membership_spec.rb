# frozen_string_literal: true

require_relative 'spec_helper'
require 'webmock/minitest'

describe 'Project co-owner collaboration' do
  let(:base_url) { SecureBiddingApp::App.config.API_URL.to_s.chomp('/') }
  let(:owner_id) { '550e8400-e29b-41d4-a716-446655440010' }
  let(:invitee_id) { '550e8400-e29b-41d4-a716-446655440011' }
  let(:project_id) { '550e8400-e29b-41d4-a716-446655440099' }
  let(:owner_token) { 'owner-token' }
  let(:invitee_token) { 'invitee-token' }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  def login(session_account, token)
    stub_request(:post, "#{base_url}/auth/authenticate")
      .to_return(
        status: 200,
        body: session_account.merge(token: token).to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    post '/auth/login', username: session_account[:username], password: 'secret'
  end

  def stub_account(account_id:, username:, token:)
    stub_request(:get, "#{base_url}/accounts/#{account_id}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: username,
          email: "#{username}@example.com",
          email_verified: true,
          profile_roles: %w[member]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def project_detail_body(policy:)
    {
      id: project_id,
      title: 'Collab Project',
      budget_cents: 50_000,
      state: 'in_progress',
      policy: policy
    }
  end

  it 'invites co-owner by username and shows pending invite UI for invitee' do
    owner = { id: owner_id, username: 'project-owner', email_verified: true }
    login(owner, owner_token)
    stub_account(account_id: owner_id, username: 'project-owner', token: owner_token)

    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .with(headers: { 'Authorization' => "Bearer #{owner_token}" })
      .to_return(
        status: 200,
        body: project_detail_body(policy: { manage_memberships: true, assigned_owner: true }).to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, "#{base_url}/projects/#{project_id}/bid_count")
      .with(headers: { 'Authorization' => "Bearer #{owner_token}" })
      .to_return(status: 200, body: { bid_count: 0 }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, "#{base_url}/projects/#{project_id}/milestones")
      .with(headers: { 'Authorization' => "Bearer #{owner_token}" })
      .to_return(status: 200, body: { milestones: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    get "/projects/#{project_id}"
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Invitee username'
    _(last_response.body).wont_include 'Account ID'

    stub_request(:post, "#{base_url}/projects/#{project_id}/memberships")
      .with(headers: { 'Authorization' => "Bearer #{owner_token}" }) do |request|
        body = JSON.parse(request.body)
        body['username'] == 'future-coowner' && body['role'] == 'project_owner'
      end
      .to_return(
        status: 202,
        body: { username: 'future-coowner', status: 'pending', role: 'project_owner' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post "/projects/#{project_id}/memberships", username: 'future-coowner'

    _(last_response.status).must_equal 302
    follow_redirect!
    _(last_response.body).must_include 'Invitation sent to future-coowner'
  end

  it 'shows accept collaboration for invitee on project detail and my projects' do
    invitee = { id: invitee_id, username: 'future-coowner', email_verified: true }
    login(invitee, invitee_token)
    stub_account(account_id: invitee_id, username: 'future-coowner', token: invitee_token)

    pending_policy = {
      show: true,
      accept_ownership: true,
      assigned_owner: false,
      admin_access: false
    }

    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .with(headers: { 'Authorization' => "Bearer #{invitee_token}" })
      .to_return(
        status: 200,
        body: project_detail_body(policy: pending_policy).to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    stub_request(:get, "#{base_url}/projects/#{project_id}/bid_count")
      .with(headers: { 'Authorization' => "Bearer #{invitee_token}" })
      .to_return(status: 200, body: { bid_count: 0 }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, "#{base_url}/projects/#{project_id}/milestones")
      .with(headers: { 'Authorization' => "Bearer #{invitee_token}" })
      .to_return(status: 200, body: { milestones: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    get "/projects/#{project_id}"
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Collaboration invite pending'
    _(last_response.body).must_include 'Accept collaboration'

    stub_request(:get, "#{base_url}/projects")
      .with(headers: { 'Authorization' => "Bearer #{invitee_token}" })
      .to_return(
        status: 200,
        body: {
          projects: [
            project_detail_body(policy: pending_policy)
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get '/projects/my?filter=invites'
    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Collaboration invites'
    _(last_response.body).must_include 'Pending invite'
    _(last_response.body).must_include 'Accept'

    stub_request(:post, "#{base_url}/projects/#{project_id}/memberships/accept")
      .with(headers: { 'Authorization' => "Bearer #{invitee_token}" })
      .to_return(status: 200, body: { role: 'project_owner' }.to_json, headers: { 'Content-Type' => 'application/json' })

    post "/projects/#{project_id}/memberships/accept"
    _(last_response.status).must_equal 302
    follow_redirect!
    _(last_response.body).must_include 'You are now a project owner'
  end
end
