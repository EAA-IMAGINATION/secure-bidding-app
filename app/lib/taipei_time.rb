# frozen_string_literal: true

module SecureBiddingApp
  # Taiwan (UTC+8) is the course/demo timezone. Heroku dynos default to UTC and
  # the app/API run in different regions, so deadlines must be normalized explicitly.
  module TaipeiTime
    OFFSET = '+08:00'
    DATETIME_LOCAL_PATTERN = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?\z/

    module_function

    def parse(value)
      str = value.to_s.strip
      return nil if str.empty?

      if (match = DATETIME_LOCAL_PATTERN.match(str))
        Time.new(
          match[1].to_i, match[2].to_i, match[3].to_i,
          match[4].to_i, match[5].to_i, (match[6] || 0).to_i,
          OFFSET
        )
      else
        Time.parse(str)
      end
    rescue ArgumentError, TypeError
      nil
    end

    def to_api_iso(value)
      parse(value)&.iso8601
    end

    def display(value)
      time = parse(value)
      return value.to_s unless time

      time.getlocal(OFFSET).strftime('%Y-%m-%d %H:%M (UTC+8)')
    end

    def input_value(value)
      time = parse(value)
      return '' unless time

      time.getlocal(OFFSET).strftime('%Y-%m-%dT%H:%M')
    end

    def future?(value)
      time = parse(value)
      time && time > Time.now
    end
  end
end
