# frozen_string_literal: true

require_relative 'spec_helper'

describe 'SecureBiddingApp::SignedMessage' do
  before do
    @saved_key = SecureBiddingApp::SignedMessage.instance_variable_get(:@signing_key)
    signing_key = RbNaCl::SigningKey.generate
    SecureBiddingApp::SignedMessage.setup(Base64.strict_encode64(signing_key.to_bytes))
  end

  after do
    SecureBiddingApp::SignedMessage.instance_variable_set(:@signing_key, @saved_key)
  end

  it 'returns data and signature envelope' do
    message = { username: 'alice', email: 'alice@example.com' }
    signed = SecureBiddingApp::SignedMessage.sign(message)

    _(signed[:data]).must_equal message
    _(signed[:signature]).must_be_kind_of String
  end

  it 'is deterministic for the same payload' do
    message = { username: 'bob' }
    _(SecureBiddingApp::SignedMessage.sign(message)).must_equal SecureBiddingApp::SignedMessage.sign(message)
  end

  it 'raises KeypairError for invalid setup input' do
    _ { SecureBiddingApp::SignedMessage.setup('not-a-base64-key!') }
      .must_raise SecureBiddingApp::SignedMessage::KeypairError
  end
end
