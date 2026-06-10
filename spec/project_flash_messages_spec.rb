# frozen_string_literal: true

require_relative 'spec_helper'
require 'webmock/minitest'

describe 'Project flash messages' do
  let(:base_url) { SecureBiddingApp::App.config.API_URL.to_s.chomp('/') }
  let(:account_id) { '550e8400-e29b-41d4-a716-446655440001' }
  let(:project_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:token) { 'owner-token' }

  before do
    WebMock.disable_net_connect!
  end

  after do
    WebMock.allow_net_connect!
  end

  def owner_session
    session = {}
    CurrentSession.new(session).store_current_account(
      'id' => account_id,
      'username' => 'project-owner',
      'token' => token,
      'email_verified' => true,
      'system_role' => 'member',
      'system_roles' => ['project_owner']
    )
    session
  end

  def stub_owner_profile
    stub_request(:get, "#{base_url}/accounts/#{account_id}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(
        status: 200,
        body: {
          id: account_id,
          username: 'project-owner',
          email_verified: true,
          system_role: 'member',
          system_roles: ['project_owner'],
          token: token
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_home_projects
    stub_request(:get, "#{base_url}/projects")
      .to_return(status: 200, body: { projects: [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def managed_project_body
    {
      id: project_id,
      title: 'Managed Project',
      description: '',
      required_documents: [],
      budget_cents: 100_000,
      state: 'published',
      bidding_deadline: '2026-06-11T08:00:00+00:00',
      policy: {
        show: true,
        update: true,
        destroy: true,
        manage_memberships: true
      }
    }
  end

  it 'does not show the project id after creating a project' do
    stub_owner_profile
    stub_home_projects
    stub_request(:post, "#{base_url}/projects")
      .to_return(status: 201, body: { id: project_id, status: 'created' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    post '/projects',
         {
           title: 'New Project',
           description: 'Brief project description',
           required_documents: "Proposal\nTimeline",
           budget_cents: '100000',
           state: 'published',
           bidding_deadline: '2026-06-11T08:00',
           nacl_public_key: 'YWJj',
           nacl_encrypted_private_key: '{"ciphertext":"x","nonce":"y","key":"z"}'
         },
         'rack.session' => owner_session

    _(last_response.status).must_equal 302
    follow_redirect!

    _(last_response.body).must_include 'Project created successfully'
    _(last_response.body).wont_include "ID: #{project_id}"
    _(last_response.body).wont_include "Project #{project_id}"
  end

  it 'does not show the project id after deleting a project' do
    stub_owner_profile
    stub_home_projects
    stub_request(:get, "#{base_url}/projects/#{project_id}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: managed_project_body.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:delete, "#{base_url}/projects/#{project_id}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 204, body: '')

    post "/projects/#{project_id}/delete", {}, 'rack.session' => owner_session

    _(last_response.status).must_equal 302
    follow_redirect!

    _(last_response.body).must_include 'Project deleted successfully'
    _(last_response.body).wont_include "Project #{project_id}"
  end
end
