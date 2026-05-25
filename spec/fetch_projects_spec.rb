# frozen_string_literal: true

require_relative 'spec_helper'
require 'ostruct'

describe 'FetchProjects Service' do
  let(:base_url) { 'http://localhost:3001/api/v1' }
  let(:service) { FetchProjects.new(OpenStruct.new(API_URL: base_url)) }

  it 'uses the published projects endpoint for the default scope' do
    stub_request(:get, "#{base_url}/projects")
      .to_return(status: 200, body: { projects: [{ id: '1', title: 'A', budget_cents: 100 }] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    response = service.call

    _(response.first['title']).must_equal 'A'
  end

  it 'does not call the removed /projects/my endpoint' do
    stub_request(:get, "#{base_url}/projects/my").to_return(status: 404)
    stub_request(:get, "#{base_url}/projects")
      .to_return(status: 200, body: { projects: [] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    response = service.call(scope: :user_projects)

    _(response).must_equal []
  end
end
