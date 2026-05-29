# frozen_string_literal: true

require 'ostruct'

module SecureBiddingApp
  # Project model representing a project resource
  class Project < OpenStruct
    def self.from_hash(data)
      new(data)
    end

    def self.from_array(list)
      (list || []).map { |item| from_hash(item) }
    end

    # Provide Hash-like access for legacy templates (project['title'])
    def [](key)
      h = to_h
      return h[key] if h.key?(key)
      return h[key.to_s] if key.is_a?(Symbol) && h.key?(key.to_s)
      return h[key.to_sym] if key.is_a?(String) && h.key?(key.to_sym)

      nil
    end

    def dig(*args)
      # Try to normalize first arg to string/symbol variants
      if args.empty?
        nil
      else
        first = args.shift
        value = self[first]
        return nil if value.nil?
        return value.dig(*args) if value.respond_to?(:dig) && args.any?
        args.empty? ? value : nil
      end
    end
  end
end
