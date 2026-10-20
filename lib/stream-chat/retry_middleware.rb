# typed: strict
# frozen_string_literal: true

require 'faraday'
require 'sorbet-runtime'

module StreamChat
  # Retries a request whose connection was dropped at the transport level.
  #
  # Why: the load balancer front end in front of the API occasionally drops
  # connections (e.g. scheduled proxy restarts). Most often an idle pooled
  # keep-alive connection is closed without a TLS close_notify, and the next
  # request on it fails with "SSL_read: unexpected eof while reading" before
  # anything is written. faraday-net_http_persistent sets
  # Net::HTTP#max_retries = 0, so nothing below this middleware retries.
  #
  # A request is retried only when repeating it is safe:
  # - any method, when the failure happened while Net::HTTP was opening or
  #   checking the connection (`connect` / `begin_transport`), so the request
  #   provably never left the client;
  # - GET, HEAD and OPTIONS also when the connection dropped later, since the
  #   server may have received them but repeating them is harmless.
  # HTTP error responses and timeouts are never retried, and a body that
  # cannot be rewound is never sent twice.
  class RetryMiddleware < Faraday::Middleware
    extend T::Sig

    MAX_RETRIES = 2
    BASE_DELAY = 0.1
    SAFE_METHODS = T.let(%i[get head options].freeze, T::Array[Symbol])
    # A Net::HTTP frame that runs before the request is written: opening the
    # socket/TLS session, or the stale-connection check of a pooled socket.
    # Matches both backtrace label styles (`connect' and 'Net::HTTP#connect').
    PRE_SEND_FRAME = T.let(%r{/net/http\.rb:\d+:in [`'](?:Net::HTTP#)?(?:connect|begin_transport)'}, Regexp)

    sig { params(env: Faraday::Env).returns(Faraday::Response) }
    def call(env)
      request_body = env.request_body
      retries = 0
      begin
        app.call(env)
      rescue Faraday::ConnectionFailed, Faraday::SSLError => e
        raise unless retries < MAX_RETRIES && retryable?(e, env.method) && rewind(request_body)

        retries += 1
        sleep(backoff(retries))
        env.request_body = request_body
        retry
      end
    end

    private

    sig { params(error: Exception, method: Symbol).returns(T::Boolean) }
    def retryable?(error, method)
      SAFE_METHODS.include?(method) || not_sent?(error)
    end

    # True when the failure was raised from Net::HTTP before the request was
    # written. The adapter wraps the original error, so walk the cause chain.
    sig { params(error: Exception).returns(T::Boolean) }
    def not_sent?(error)
      current = T.let(error, T.nilable(Exception))
      while current
        return true if (current.backtrace || []).any? { |frame| PRE_SEND_FRAME.match?(frame) }

        current = current.cause
      end
      false
    end

    # Strings (and no body) can be sent again as is; IO bodies, such as
    # multipart uploads, only when they can be rewound to the start.
    sig { params(body: T.untyped).returns(T::Boolean) }
    def rewind(body)
      return true unless body.respond_to?(:read)
      return false unless body.respond_to?(:rewind)

      body.rewind
      true
    rescue IOError, SystemCallError
      false
    end

    # ~100ms then ~200ms, with jitter so clients that lost connections at the
    # same moment do not reconnect in lockstep.
    sig { params(retry_number: Integer).returns(Float) }
    def backoff(retry_number)
      delay = BASE_DELAY * (1 << (retry_number - 1))
      delay + (rand * delay / 2)
    end
  end
end
