# frozen_string_literal: true

require_relative 'spec_helper'
require 'webmock/minitest'
require 'ostruct'

class CreateAccountTest < Minitest::Test
  def setup
    @base = 'http://localhost:3000/api/v1'
    @service = SecureBiddingApp::CreateAccount.new(OpenStruct.new(API_URL: @base))
  end

  def test_validation_error
    assert_raises SecureBiddingApp::CreateAccount::ValidationError do
      @service.call(email: '', username: 'u', password: 'p')
    end
  end

  def test_successful_call
    stub_request(:post, "#{@base}/accounts").to_return(status: 201, body: '{"username":"jdoe"}',
                                                       headers: { 'Content-Type' => 'application/json' })
    res = @service.call(email: 'a@b.com', username: 'jdoe', password: 'secret')
    assert_equal({ 'username' => 'jdoe' }, res)
  end
end
