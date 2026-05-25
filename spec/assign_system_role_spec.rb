# frozen_string_literal: true

require_relative 'spec_helper'
require 'ostruct'

describe 'AssignSystemRole Service' do
  let(:base_url) { 'http://localhost:3001/api/v1' }
  let(:service) { AssignSystemRole.new(OpenStruct.new(API_URL: base_url)) }

  it 'posts the API role payload using role' do
    stub_request(:post, "#{base_url}/accounts/123/system_roles")
      .with(body: { role: 'system_admin' }.to_json)
      .to_return(status: 201, body: { account_id: '123', role: 'system_admin', status: 'assigned' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    response = service.call(account_id: '123', system_role: 'system_admin')

    _(response['role']).must_equal 'system_admin'
  end

  it 'rejects unsupported legacy roles' do
    _ { service.call(account_id: '123', system_role: 'admin') }.must_raise AssignSystemRole::ValidationError
  end
end
