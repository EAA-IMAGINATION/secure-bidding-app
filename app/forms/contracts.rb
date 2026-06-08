# frozen_string_literal: true

require 'dry-validation'

module SecureBiddingApp
  module Forms
    # UUID regex pattern for validation
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze

    # Login form validation schema
    class Login < Dry::Validation::Contract
      params do
        required(:username).filled(:string)
        required(:password).filled(:string)
      end
    end

    # Registration form validation schema
    class Register < Dry::Validation::Contract
      params do
        required(:username).filled(:string)
        required(:email).filled(:string, format?: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
      end
    end

    # Verification form validation schema with password confirmation matching
    class Verify < Dry::Validation::Contract
      params do
        required(:password).filled(:string, min_size?: 8)
        required(:password_confirm).filled(:string)
      end

      rule(:password_confirm, :password) do
        if values[:password] != values[:password_confirm]
          key.failure('must match password')
        end
      end
    end

    # Project creation/edit form validation schema
    class ProjectNew < Dry::Validation::Contract
      params do
        required(:title).filled(:string)
        required(:budget_cents).filled(:integer, gteq?: 0)
        required(:state).filled(:string, included_in?: %w[saved published])
        required(:bidding_deadline).filled(:string)
        required(:nacl_public_key).filled(:string)
        required(:nacl_encrypted_private_key).filled(:string)
      end

      rule(:bidding_deadline) do
        next if value.to_s.empty?

        begin
          deadline = DateTime.iso8601(value)
          if deadline <= DateTime.now
            key.failure('must be in the future')
          end
        rescue ArgumentError, TypeError
          key.failure('must be a valid ISO 8601 date and time')
        end
      end

      rule(:nacl_public_key) do
        next if value.to_s.empty?

        unless value.match?(/\A[A-Za-z0-9+\/=]+\z/)
          key.failure('must be valid base64')
        end
      end

      rule(:nacl_encrypted_private_key) do
        next if value.to_s.empty?

        begin
          parsed = JSON.parse(value)
          unless parsed.is_a?(Hash) && parsed['ciphertext'] && parsed['nonce'] && parsed['key']
            key.failure('must contain ciphertext, nonce, and key')
          end
        rescue JSON::ParserError
          key.failure('must be valid JSON with ciphertext, nonce, and salt')
        end
      end
    end

    # Bid submission form validation schema
    class BidSubmission < Dry::Validation::Contract
      params do
        required(:project_id).filled(:string)
        required(:contractor_alias).filled(:string)
        required(:encrypted_bid_amount).filled(:string)
        required(:encrypted_proposal_text).filled(:string)
      end

      rule(:project_id) do
        next if value.to_s.empty?

        unless value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          key.failure('must be a valid UUID')
        end
      end

      rule(:encrypted_bid_amount) do
        next if value.to_s.empty?

        begin
          parsed = JSON.parse(value)
          unless parsed.is_a?(Hash) && parsed['ciphertext'] && parsed['nonce']
            key.failure('must be valid JSON with ciphertext and nonce')
          end
        rescue JSON::ParserError
          key.failure('must be valid JSON')
        end
      end

      rule(:encrypted_proposal_text) do
        next if value.to_s.empty?

        begin
          parsed = JSON.parse(value)
          unless parsed.is_a?(Hash) && parsed['ciphertext'] && parsed['nonce']
            key.failure('must be valid JSON with ciphertext and nonce')
          end
        rescue JSON::ParserError
          key.failure('must be valid JSON')
        end
      end
    end

    # Admin user edit form validation schema
    class AdminUserEdit < Dry::Validation::Contract
      params do
        required(:email).filled(:string, format?: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
      end
    end

    # Account profile edit form validation schema
    class AccountEdit < Dry::Validation::Contract
      EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

      params do
        required(:username).filled(:string)
        required(:email).filled(:string, format?: EMAIL_REGEX)
        optional(:password).maybe(:string)
        optional(:password_confirm).maybe(:string)
        optional(:current_password).maybe(:string)
      end

      rule(:password) do
        next if value.nil? || value.to_s.empty?

        key.failure('must be at least 8 characters') if value.to_s.length < 8
      end

      rule(:password_confirm, :password) do
        next if values[:password].to_s.empty?

        key.failure('must match password') if values[:password] != values[:password_confirm]
      end

      rule(:current_password, :password) do
        next if values[:password].to_s.empty?

        key.failure('is required when changing password') if values[:current_password].to_s.empty?
      end
    end
  end
end
