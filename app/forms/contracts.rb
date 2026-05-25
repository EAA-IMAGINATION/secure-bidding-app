# frozen_string_literal: true

require 'dry-validation'

module SecureBiddingApp
  module Forms
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
      end
    end

    # Bid submission form validation schema
    class BidSubmission < Dry::Validation::Contract
      params do
        required(:contractor_alias).filled(:string)
        required(:plaintext_bid).filled(:string)
      end
    end

    # Admin User form validation schema (Create User)
    class AdminUser < Dry::Validation::Contract
      params do
        required(:username).filled(:string)
        required(:email).filled(:string, format?: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
        required(:password).filled(:string, min_size?: 8)
      end
    end

    # Admin User edit form validation schema
    class AdminUserEdit < Dry::Validation::Contract
      params do
        required(:email).filled(:string, format?: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
      end
    end
  end
end
