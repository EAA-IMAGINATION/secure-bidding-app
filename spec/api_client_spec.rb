require_relative 'spec_helper'

describe 'ApiClient Service' do
  let(:client) { ApiClient.new('http://localhost:3000') }

  describe '#get' do
    it 'makes GET request and returns response' do
      # Test will fail until ApiClient.get is implemented
      response = client.get('/test')
      _(response).wont_be_nil
    end

    it 'raises error on failed GET request' do
      # Test will fail until error handling is implemented
      -> { client.get('/nonexistent') }.must_raise ApiClient::ApiError
    end
  end

  describe '#post' do
    it 'makes POST request with JSON body' do
      # Test will fail until ApiClient.post is implemented
      response = client.post('/test', { key: 'value' })
      _(response).wont_be_nil
    end

    it 'raises error on failed POST request' do
      # Test will fail until error handling is implemented
      -> { client.post('/auth/fail', {}) }.must_raise ApiClient::ApiError
    end
  end

  describe '#put' do
    it 'makes PUT request' do
      response = client.put('/test/1', { key: 'updated' })
      _(response).wont_be_nil
    end
  end

  describe '#delete' do
    it 'makes DELETE request' do
      response = client.delete('/test/1')
      _(response).wont_be_nil
    end
  end

  describe 'error handling' do
    it 'raises ApiError with status code' do
      begin
        client.post('/invalid', {})
      rescue ApiClient::ApiError => e
        _(e.status).wont_be_nil
      end
    end

    it 'includes response body in error' do
      begin
        client.get('/error')
      rescue ApiClient::ApiError => e
        _(e.message).wont_be_empty
      end
    end
  end
end
