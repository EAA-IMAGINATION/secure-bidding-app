# frozen_string_literal: true

require 'ostruct'

module SecureBiddingApp
  # Parser model that wraps an Account API envelope and exposes helpers.
  class Account
    attr_reader :data, :auth_token

    def self.from_hash(data, auth_token = nil)
      new(data || {}, auth_token)
    end

    def self.from_array(list)
      (list || []).map { |item| from_hash(item) }
    end

    def initialize(data, auth_token = nil)
      @data = data || {}
      @auth_token = auth_token
    end

    # Hash-like access for templates/controllers that still use ['key']
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

    def logged_in?
      !@data.nil? && !@auth_token.nil?
    end

    def id
      @data['id']
    end

    def username
      @data['username']
    end

    def email
      @data['email']
    end

    def capabilities
      @data['capabilities'] || {}
    end

    def system_roles
      dig('include', 'system_roles') || @data['system_roles'] || []
    end

    # Prefer API-provided capability booleans; fall back to legacy system_role checks.
    def admin?
      caps = capabilities
      return true if caps['system_admin'] || caps['admin']

      # legacy checks
      @data['system_role'] == 'admin' || system_roles.any? { |r| r == 'admin' || r == 'system_admin' }
    end

    def can_create_projects?
      caps = capabilities
      return caps['can_create_projects'] if caps.key?('can_create_projects')

      !admin? && email_verified?
    end

    def email_verified?
      value = @data['email_verified']
      return true if value == true || value.to_s == 'true'
      return false if value == false || value.to_s == 'false'

      !@data['email_verified_at'].to_s.strip.empty?
    end

    def can_manage_accounts?
      caps = capabilities
      return caps['can_manage_accounts'] if caps.key?('can_manage_accounts')

      admin?
    end

    # Allow existing code that expects a token in the account hash
    def token
      @data['token'] || @auth_token
    end
  end
end
