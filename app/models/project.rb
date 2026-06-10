# frozen_string_literal: true

module SecureBiddingApp
  # Parser model that wraps a Project API envelope and exposes helpers.
  class Project
    POLICY_ACTION_MAP = {
      'edit' => 'update',
      'delete' => 'destroy',
      'create_bid' => 'bid',
      'submit_bid' => 'bid',
      'create' => 'create',
      'view_bids' => 'view_bid_submissions',
      'manage_owners' => 'manage_memberships',
      'is_owner' => 'manage_memberships',
      'view_bid_count' => 'view_bid_count',
      'manage_milestones' => 'manage_milestones',
      'award_bid' => 'award_bid',
      'request_payment' => 'request_payment',
      'process_payment' => 'process_payment',
      'acknowledge_payment' => 'acknowledge_payment',
      'view_as_awarded_bidder' => 'view_as_awarded_bidder'
    }.freeze

    def self.from_hash(data)
      new(data || {})
    end

    def self.from_array(list)
      (list || []).map { |item| from_hash(item) }
    end

    def initialize(data)
      @data = data || {}
    end

    # Provide Hash-like access for legacy templates (project['title'])
    def [](key)
      return @data[key] if @data.key?(key)
      return @data[key.to_s] if key.is_a?(Symbol) && @data.key?(key.to_s)
      return @data[key.to_sym] if key.is_a?(String) && @data.key?(key.to_sym)

      nil
    end

    def dig(*args)
      @data.dig(*args)
    end

    def to_h
      @data
    end

    def policy
      @data['policy'] || {}
    end

    def allowed?(action)
      summary = policy
      return false unless summary.is_a?(Hash) && !summary.empty?

      key = action.to_s
      candidate = POLICY_ACTION_MAP[key] || key
      variants = [candidate, candidate.gsub('-', '_'), candidate.gsub(' ', '_'), "#{candidate}_allowed"]
      variants.any? { |k| summary[k] || summary[k.to_sym] }
    end
  end
end
