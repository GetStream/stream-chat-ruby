# frozen_string_literal: true

# lib/stream_rate_limits.rb

module StreamChat
  class StreamRateLimits
    attr_reader :limit
    attr_reader :remaining
    attr_reader :reset

    def initialize(limit, remaining, reset)
      @limit = limit.to_i
      @remaining = remaining.to_i
      @reset = Time.at(reset.to_i)
    end
  end
end
