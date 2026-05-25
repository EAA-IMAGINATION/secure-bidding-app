# frozen_string_literal: true

require 'ostruct'

module SecureBiddingApp
  # Account model representing an account resource
  class Account < OpenStruct
    def self.from_hash(data)
      new(data)
    end

    def self.from_array(list)
      list.map { |item| from_hash(item) }
    end
  end
end
