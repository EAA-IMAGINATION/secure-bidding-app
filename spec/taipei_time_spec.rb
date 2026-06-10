# frozen_string_literal: true

require_relative 'spec_helper'

describe SecureBiddingApp::TaipeiTime do
  it 'parses datetime-local values as Taiwan time' do
    time = SecureBiddingApp::TaipeiTime.parse('2026-06-10T22:30')
    _(time.iso8601).must_equal '2026-06-10T22:30:00+08:00'
  end

  it 'formats stored instants for display in UTC+8' do
    display = SecureBiddingApp::TaipeiTime.display('2026-06-10T14:30:00Z')
    _(display).must_equal '2026-06-10 22:30 (UTC+8)'
  end

  it 'formats stored instants for datetime-local inputs' do
    value = SecureBiddingApp::TaipeiTime.input_value('2026-06-10T14:30:00Z')
    _(value).must_equal '2026-06-10T22:30'
  end
end
