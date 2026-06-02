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
end
