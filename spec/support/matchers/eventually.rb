# frozen_string_literal: true

# Block matcher that retries `expect { ... }` against an inner matcher until
# it passes or the budget runs out. Designed for the eventually-consistent
# bits of the shared-CI backend (e.g. create_command -> get_command races).
#
#   expect { client.get_command(name) }.to eventually(include('name' => name))
#
# Tweak the budget with chainable `.with_retries(n)` / `.every(seconds)`.
RSpec::Matchers.define :eventually do |inner_matcher|
  supports_block_expectations

  match do |block|
    @retries = (defined?(@retries_value) && @retries_value) || 3
    @interval = (defined?(@interval_value) && @interval_value) || 1
    @last_actual = nil
    @last_error = nil
    attempts = 0
    loop do
      begin
        @last_actual = block.call
        break true if inner_matcher.matches?(@last_actual)
      rescue StandardError, RSpec::Expectations::ExpectationNotMetError => e
        @last_error = e
      end
      attempts += 1
      break false if attempts >= @retries

      sleep(@interval)
    end
  end

  chain :with_retries do |n|
    @retries_value = n
  end

  chain :every do |seconds|
    @interval_value = seconds
  end

  failure_message do |_block|
    msg = "expected block to eventually #{inner_matcher.description}"
    msg += "; last value: #{@last_actual.inspect}" unless @last_actual.nil?
    msg += "; last error: #{@last_error.message}" if @last_error
    msg
  end
end
