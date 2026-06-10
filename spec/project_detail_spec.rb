# frozen_string_literal: true

require_relative 'spec_helper'

describe 'GET /projects/:id' do
  include Rack::Test::Methods

  def app
    SecureBiddingApp::App.freeze.app
  end

  let(:base_url) { SecureBiddingApp::App.config.API_URL }
  let(:project_id) { '00000000-0000-0000-0000-000000000099' }

  it 'renders a friendly message when the API returns 404' do
    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .to_return(status: 404, body: { error: 'Project not found' }.to_json)

    get "/projects/#{project_id}"

    _(last_response.status).must_equal 404
    _(last_response.body).must_include 'could not be loaded'
    _(last_response.body).wont_include "undefined method"
  end

  it 'renders a friendly message when the API returns 403' do
    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .to_return(status: 403, body: { error: 'Forbidden: you do not have access to this project' }.to_json)

    get "/projects/#{project_id}"

    _(last_response.status).must_equal 403
    _(last_response.body).must_include 'could not be loaded'
  end

  it 'clears an expired session and renders public project detail instead of 500' do
    session = {}
    CurrentSession.new(session).store_current_account(
      'id' => '00000000-0000-0000-0000-000000000001',
      'username' => 'stale-user',
      'token' => 'expired-token',
      'email_verified' => true
    )

    stub_request(:get, "#{base_url}/accounts/00000000-0000-0000-0000-000000000001")
      .with(headers: { 'Authorization' => 'Bearer expired-token' })
      .to_return(status: 401, body: { error: 'Invalid auth token' }.to_json)

    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .with(headers: { 'Authorization' => 'Bearer expired-token' })
      .to_return(status: 401, body: { error: 'Invalid auth token' }.to_json)

    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .with { |request| request.headers['Authorization'].nil? }
      .to_return(
        status: 200,
        body: {
          id: project_id,
          title: 'Public Project',
          description: nil,
          required_documents: [],
          budget_cents: 50_000,
          state: 'published',
          bidding_deadline: '2026-06-11T08:00:00+00:00',
          nacl_public_key: 'abc',
          policy: { show: true }
        }.to_json
      )

    get "/projects/#{project_id}", {}, 'rack.session' => session

    _(last_response.status).must_equal 200
    _(last_response.body).must_include 'Public Project'
    _(last_response.body).must_include '/auth/login'
  end
end
