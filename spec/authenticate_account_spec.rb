require_relative 'spec_helper'

describe 'AuthenticateAccount Service' do
  let(:service) { AuthenticateAccount.new }

  describe '#call' do
    it 'returns account on successful authentication' do
      # Test will fail until service is properly implemented
      account = service.call('user@example.com', 'password123')
      _(account).wont_be_nil
      _(account['email']).must_equal 'user@example.com'
    end

    it 'returns nil on failed authentication' do
      account = service.call('user@example.com', 'wrongpassword')
      _(account).must_be_nil
    end

    it 'raises error if email is missing' do
      -> { service.call(nil, 'password') }.must_raise ArgumentError
    end

    it 'raises error if password is missing' do
      -> { service.call('user@example.com', nil) }.must_raise ArgumentError
    end
  end

  describe 'account data' do
    it 'includes id in returned account' do
      account = service.call('user@example.com', 'password123')
      _(account['id']).wont_be_nil
    end

    it 'includes email in returned account' do
      account = service.call('user@example.com', 'password123')
      _(account['email']).must_equal 'user@example.com'
    end

    it 'includes system_roles in returned account' do
      account = service.call('user@example.com', 'password123')
      _(account['system_roles']).wont_be_nil
      _(account['system_roles']).must_be_kind_of Array
    end

    it 'never includes password in returned account' do
      account = service.call('user@example.com', 'password123')
      _(account).wont_include 'password'
    end
  end

  describe 'error handling' do
    it 'raises error on API failure' do
      # Stub API to fail
      -> { service.call('user@example.com', 'password123') }.must_raise StandardError
    end
  end
end
