# frozen_string_literal: true

require_relative 'spec_helper'
require 'webmock/minitest'

describe 'Frontend UI flows' do
  let(:base_url) { 'http://localhost:3000/api/v1' }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  it 'logs in through the UI and persists the session' do
    stub_request(:post, "#{base_url}/auth/authenticate")
      .with(body: hash_including(username: 'demo-bidder', password: 'bidder-pass-123'))
      .to_return(status: 200, body: {
        id: 'account-1',
        username: 'demo-bidder',
        email: 'bidder@example.com',
        system_role: 'member',
        system_roles: ['bidder'],
        token: 'token-123'
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/projects")
      .to_return(status: 200, body: { projects: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    post '/auth/login', username: 'demo-bidder', password: 'bidder-pass-123'

    _(last_response.status).must_equal 302
    _(last_response.location).must_equal '/'

    follow_redirect!

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Welcome back, demo-bidder!'
    _(last_response.body).must_include '/auth/logout'
  end

  it 'submits a bid through the UI using the logged-in auth token' do
    project_id = 'project-123'

    stub_request(:post, "#{base_url}/auth/authenticate")
      .with(body: hash_including(username: 'demo-bidder', password: 'bidder-pass-123'))
      .to_return(status: 200, body: {
        id: 'account-1',
        username: 'demo-bidder',
        email: 'bidder@example.com',
        system_role: 'member',
        system_roles: ['bidder'],
        token: 'token-123'
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/projects")
      .to_return(status: 200, body: { projects: [] }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .to_return(status: 200, body: {
        id: project_id,
        title: 'Website Redesign',
        budget_cents: 150_000,
        state: 'published'
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    stub_request(:post, "#{base_url}/projects/#{project_id}/bids")
      .with(
        headers: hash_including('Authorization' => 'Bearer token-123'),
        body: hash_including(
          bidder_account_id: 'account-1',
          contractor_alias: 'demo-bidder',
          plaintext_bid: '2000'
        )
      )
      .to_return(status: 201, body: { id: 'bid-1', status: 'created' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    post '/auth/login', username: 'demo-bidder', password: 'bidder-pass-123'
    follow_redirect!

    post "/projects/#{project_id}/bids", contractor_alias: 'demo-bidder', plaintext_bid: '2000'

    _(last_response.status).must_equal 302
    _(last_response.location).must_equal "/projects/#{project_id}"

    follow_redirect!

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Website Redesign'
  end
end
