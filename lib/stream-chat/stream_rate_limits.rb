# typed: strict
# frozen_string_literal: true

module StreamChat
  class StreamRateLimits
    extend T::Sig

    sig { returns(Integer) }
    attr_reader :limit

    sig { returns(Integer) }
    attr_reader :remaining

    sig { returns(Time) }
    attr_reader :reset

    sig { params(limit: String, remaining: String, reset: String).void }
    def initialize(limit, remaining, reset)
      @limit = T.let(limit.to_i, Integer)
      @remaining = T.let(remaining.to_i, Integer)
      @reset = T.let(Time.at(reset.to_i), Time)
    end
  end
end
