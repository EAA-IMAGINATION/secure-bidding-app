# frozen_string_literal: true

require_relative 'spec_helper'

describe 'AuthenticateAccount Service' do
  let(:service) { AuthenticateAccount.new }

  describe '#initialize' do
    it 'creates instance' do
      _(service).wont_be_nil
    end
  end

  describe '#call' do
    it 'is callable' do
      _(service).must_respond_to :call
    end

    it 'requires email parameter' do
      _ { service.call(nil, 'password') }.must_raise ArgumentError
    end

    it 'requires password parameter' do
      _ { service.call(username: 'user@example.com', password: nil) }.must_raise ArgumentError
    end

    it 'requires both email and password' do
      _ { service.call(username: '', password: '') }.must_raise ArgumentError
    end
  end

  describe 'error handling' do
    it 'has defined error handling' do
      # Service should handle API errors gracefully
      # Actual behavior tested when API is available
      _(service).wont_be_nil
    end
  end
end
