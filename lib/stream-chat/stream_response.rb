# frozen_string_literal: true

# lib/stream_response.rb
# typed: true

require 'stream-chat/stream_rate_limits'

module StreamChat
  class StreamResponse < Hash
    attr_reader :rate_limit
    attr_reader :status_code
    attr_reader :headers

    def initialize(hash, response)
      super(nil)
      merge!(hash)

      if response.headers.key?('X-Ratelimit-Limit')
        @rate_limit = StreamRateLimits.new(
          response.headers['X-Ratelimit-Limit'],
          response.headers['X-Ratelimit-Remaining'],
          response.headers['X-Ratelimit-Reset']
        )
      end

      @status_code = response.status
      @headers = response.headers
    end
  end
end
