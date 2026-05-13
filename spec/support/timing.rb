# frozen_string_literal: true

# Per-test wall-clock timing emitted to STDOUT so CI logs surface which
# example is in flight when a runner stalls. The default `--format
# documentation` reporter prints test names but not timing; `--profile`
# only summarises at the end (no help when the run hangs before reaching
# the summary). This hook fills the gap: every example logs
# `[timing] start ...` on enter and `[timing] N.NN s ...` on exit with
# its full description path, so an unattended runner stuck mid-test
# leaves a clear breadcrumb.
RSpec.configure do |config|
  config.before(:each) do |example|
    example.metadata[:timing_started_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    warn "[timing] start #{example.full_description}"
  end

  config.after(:each) do |example|
    started_at = example.metadata[:timing_started_at]
    next unless started_at

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    status = example.exception ? 'fail' : 'pass'
    warn format(
      '[timing] %<elapsed>.2f s %<status>s %<description>s',
      elapsed: elapsed,
      status: status,
      description: example.full_description
    )
  end
end
