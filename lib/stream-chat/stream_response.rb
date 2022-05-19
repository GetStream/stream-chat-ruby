# typed: true
# frozen_string_literal: true

require 'stream-chat/stream_rate_limits'
require 'stream-chat/types'

module StreamChat
  class StreamResponse < Hash
    extend T::Sig

    sig { returns(StreamRateLimits) }
    attr_reader :rate_limit

    sig { returns(Integer) }
    attr_reader :status_code

    sig { returns(StringKeyHash) }
    attr_reader :headers

    sig { params(hash: T::Hash[T.untyped, T.untyped], response: Faraday::Response).void }
    def initialize(hash, response)
      super(nil)
      merge!(hash)

      if response.headers.key?('X-Ratelimit-Limit')
        @rate_limit = T.let(StreamRateLimits.new(
                              T.must(response.headers['X-Ratelimit-Limit']),
                              T.must(response.headers['X-Ratelimit-Remaining']),
                              T.must(response.headers['X-Ratelimit-Reset'])
                            ), StreamRateLimits)
      end

      @status_code = T.let(response.status, Integer)
      @headers = T.let(response.headers, StringKeyHash)
    end
  end
end
