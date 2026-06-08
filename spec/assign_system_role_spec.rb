# frozen_string_literal: true

require_relative 'spec_helper'
require 'ostruct'

describe 'AssignSystemRole Service' do
  let(:base_url) { 'http://localhost:3000/api/v1' }
  let(:service) { AssignSystemRole.new(OpenStruct.new(API_URL: base_url)) }

  it 'allows promoting an account to admin' do
    stub_request(:post, "#{base_url}/accounts/123/system_roles")
      .with(body: { role: 'admin' }.to_json)
      .to_return(status: 201, body: { account_id: '123', role: 'admin', status: 'assigned' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    response = service.call(account_id: '123', system_role: 'admin')

    _(response['role']).must_equal 'admin'
  end

  it 'allows demoting an account to member' do
    stub_request(:post, "#{base_url}/accounts/123/system_roles")
      .with(body: { role: 'member' }.to_json)
      .to_return(status: 201, body: { account_id: '123', role: 'member', status: 'assigned' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    response = service.call(account_id: '123', system_role: 'member')

    _(response['role']).must_equal 'member'
  end

  it 'rejects unknown roles' do
    _ { service.call(account_id: '123', system_role: 'superuser') }.must_raise AssignSystemRole::ValidationError
  end
end
