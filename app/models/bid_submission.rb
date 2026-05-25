# frozen_string_literal: true

require 'ostruct'

module SecureBiddingApp
  # BidSubmission model representing a bid submission resource
  class BidSubmission < OpenStruct
    def self.from_hash(data)
      new(data)
    end

    def self.from_array(list)
      list.map { |item| from_hash(item) }
    end
  end
end
