# frozen_string_literal: true

require_relative 'spec_helper'
require 'json'
require 'webmock/minitest'

describe 'My projects page' do
  let(:base_url) { SecureBiddingApp::App.config.API_URL.to_s.chomp('/') }
  let(:account_id) { 'owner-123' }
  let(:token) { 'owner-token' }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  def stub_owner_profile
    stub_request(:get, "#{base_url}/accounts/#{account_id}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: 'owner-user',
          email: 'owner@example.com',
          email_verified: true,
          profile_roles: %w[member project_owner]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def login_as_owner
    stub_request(:post, "#{base_url}/auth/authenticate")
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: 'owner-user',
          email: 'owner@example.com',
          email_verified: true,
          token: token
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    post '/auth/login', username: 'owner-user', password: 'secret'
    _(last_response.status).must_equal 302
  end

  def project_payload(id:, title:, state:, owner: true, freelancer: false)
    policy = {}
    policy['manage_memberships'] = true if owner
    policy['view_as_awarded_bidder'] = true if freelancer
    {
      id: id,
      title: title,
      budget_cents: 120_000,
      state: state,
      policy: policy
    }
  end

  it 'shows owned and freelancer sections with closed filters' do
    login_as_owner
    stub_owner_profile

    stub_request(:get, "#{base_url}/projects")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          projects: [
            project_payload(id: 'open-owned', title: 'Open Owned', state: 'published', owner: true),
            project_payload(id: 'closed-owned', title: 'Closed Owned', state: 'closed', owner: true),
            project_payload(id: 'closed-freelancer', title: 'Closed Freelancer', state: 'closed',
                            owner: false, freelancer: true)
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get '/projects/my'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Owned projects'
    _(last_response.body).must_include 'Freelancer projects'
    _(last_response.body).must_include 'Closed Owned'
    _(last_response.body).must_include 'Closed Freelancer'
    _(last_response.body).must_include 'href="/projects/my?filter=closed"'
  end

  it 'shows in-progress and payment-pending projects in the active filter' do
    login_as_owner
    stub_owner_profile

    stub_request(:get, "#{base_url}/projects")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          projects: [
            project_payload(id: 'in-progress-owned', title: 'In Progress Owned', state: 'in_progress', owner: true),
            project_payload(id: 'payment-pending-freelancer', title: 'Payment Pending Freelancer',
                            state: 'payment_pending', owner: false, freelancer: true),
            project_payload(id: 'closed-owned', title: 'Closed Owned', state: 'closed', owner: true)
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get '/projects/my?filter=active'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Active as owner'
    _(last_response.body).must_include 'Active as freelancer'
    _(last_response.body).must_include 'In Progress Owned'
    _(last_response.body).must_include 'In progress'
    _(last_response.body).must_include 'Payment Pending Freelancer'
    _(last_response.body).must_include 'Payment pending'
    _(last_response.body).wont_include 'Closed Owned'
  end

  it 'shows only closed owner and freelancer projects in the closed filter' do
    login_as_owner
    stub_owner_profile

    stub_request(:get, "#{base_url}/projects")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          projects: [
            project_payload(id: 'open-owned', title: 'Open Owned', state: 'published', owner: true),
            project_payload(id: 'closed-owned', title: 'Closed Owned', state: 'closed', owner: true),
            project_payload(id: 'closed-freelancer', title: 'Closed Freelancer', state: 'closed',
                            owner: false, freelancer: true)
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    get '/projects/my?filter=closed'

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Closed as owner'
    _(last_response.body).must_include 'Completed as freelancer'
    _(last_response.body).must_include 'Closed Owned'
    _(last_response.body).must_include 'Closed Freelancer'
    _(last_response.body).wont_include 'Open Owned'
  end
end
