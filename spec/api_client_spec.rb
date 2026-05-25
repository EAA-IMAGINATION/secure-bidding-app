# frozen_string_literal: true

require_relative 'spec_helper'

describe 'ApiClient Service' do
  let(:client) { ApiClient.new('http://localhost:3001') }

  describe '#initialize' do
    it 'stores base URL' do
      url = 'http://api.example.com'
      c = ApiClient.new(url)
      _(c).wont_be_nil
    end
  end

  describe 'error classes' do
    it 'defines ApiError exception class' do
      _(ApiClient::ApiError).wont_be_nil
    end

    it 'ApiError stores status code' do
      error = ApiClient::ApiError.new(404, 'Not Found')
      _(error.status).must_equal 404
    end

    it 'ApiError stores response body' do
      error = ApiClient::ApiError.new(500, { 'message' => 'Server Error' })
      _(error.body).must_equal({ 'message' => 'Server Error' })
    end

    it 'ApiError message from hash body' do
      error = ApiClient::ApiError.new(400, { 'message' => 'Bad Request' })
      _(error.message).must_equal 'Bad Request'
    end

    it 'ApiError message from string body' do
      error = ApiClient::ApiError.new(400, 'Bad Request')
      _(error.message).must_equal 'Bad Request'
    end
  end

  describe 'HTTP methods exist' do
    it 'responds to get' do
      _(client).must_respond_to :get
    end

    it 'responds to post' do
      _(client).must_respond_to :post
    end

    it 'responds to put' do
      _(client).must_respond_to :put
    end

    it 'responds to delete' do
      _(client).must_respond_to :delete
    end
  end
end
