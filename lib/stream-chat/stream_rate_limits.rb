# typed: strict
# frozen_string_literal: true

module StreamChat
  class StreamRateLimits
    extend T::Sig
    T::Configuration.default_checked_level = :never
    # For now we disable runtime type checks.
    # We will enable it with a major bump in the future,
    # but for now, let's just run a static type check.

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
