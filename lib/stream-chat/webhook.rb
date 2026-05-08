# typed: strict
# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'
require 'sorbet-runtime'
require 'stringio'
require 'zlib'

require 'stream-chat/errors'

module StreamChat
  # Stateless helpers implementing the cross-SDK webhook contract documented at
  # https://getstream.io/chat/docs/node/webhooks_overview/.
  #
  # The composite functions (`verify_and_parse_webhook`, `verify_and_parse_sqs`,
  # `verify_and_parse_sns`) are the recommended entry points. The primitives
  # they compose (`ungzip_payload`, `decode_sqs_payload`, `decode_sns_payload`,
  # `verify_signature`, `parse_event`) are exposed so callers can build custom
  # flows or run individual steps in isolation.
  #
  # The Ruby SDK currently returns the parsed JSON as a `Hash`; typed event
  # classes will land in a future release.
  module Webhook # rubocop:disable Metrics/ModuleLength
    extend T::Sig

    GZIP_MAGIC = T.let("\x1f\x8b\x08".b.freeze, String)

    # Coerces the webhook body into a binary `String` regardless of whether
    # the caller hands us a `String` (HTTP `request.raw_post`) or an array of
    # bytes (which is what some Ruby SQS clients yield when the message body
    # is binary safe).
    sig { params(body: T.any(String, T::Array[Integer])).returns(String) }
    def self.normalize_body(body)
      raw =
        if body.is_a?(Array)
          body.pack('C*')
        else
          String.new(body)
        end
      raw.force_encoding(Encoding::ASCII_8BIT)
    end

    # Returns `body` unchanged unless it starts with the gzip magic
    # (`1f 8b 08`), in which case the gzip stream is inflated and the
    # decompressed bytes are returned.
    #
    # Magic-byte detection (rather than relying on a header) keeps the same
    # handler correct when middleware - Rack, Rails - auto-decompresses the
    # request before your code sees it.
    sig { params(body: T.any(String, T::Array[Integer])).returns(String) }
    def self.ungzip_payload(body)
      raw = normalize_body(body)
      return raw unless raw.start_with?(GZIP_MAGIC)

      begin
        Zlib::GzipReader.new(StringIO.new(raw)).read.force_encoding(Encoding::ASCII_8BIT)
      rescue Zlib::Error => e
        raise WebhookSignatureError, "failed to decompress gzip payload: #{e.message}"
      end
    end

    # Reverses the SQS firehose envelope: the message `Body` is base64-decoded
    # and, when the result begins with the gzip magic, gzip-decompressed. The
    # same call works whether or not Stream is currently compressing payloads.
    sig { params(body: String).returns(String) }
    def self.decode_sqs_payload(body)
      decoded =
        begin
          Base64.strict_decode64(body)
        rescue ArgumentError => e
          raise WebhookSignatureError, "failed to base64-decode payload: #{e.message}"
        end
      ungzip_payload(decoded)
    end

    # Identical to `decode_sqs_payload`; exposed under both names so call sites
    # read intent.
    sig { params(message: String).returns(String) }
    def self.decode_sns_payload(message)
      decode_sqs_payload(message)
    end

    # Constant-time HMAC-SHA256 verification of `signature` against the digest
    # of `body` keyed by `secret`.
    #
    # The signature is always computed over the **uncompressed** JSON bytes,
    # so callers that decoded a gzipped or base64-wrapped payload must pass
    # the inflated bytes here.
    sig do
      params(
        body: T.any(String, T::Array[Integer]),
        signature: String,
        secret: String
      ).returns(T::Boolean)
    end
    def self.verify_signature(body, signature, secret)
      raw = normalize_body(body)
      expected = OpenSSL::HMAC.hexdigest('SHA256', secret, raw)
      constant_time_equal?(expected, signature)
    end

    # Parse a JSON-encoded webhook event into a `Hash`.
    #
    # The Ruby SDK currently returns the parsed JSON as a `Hash`; typed event
    # classes will land in a future release. The function name matches the
    # documented primitive so callers can swap in a typed parser later without
    # changing call sites.
    sig { params(payload: String).returns(T::Hash[String, T.untyped]) }
    def self.parse_event(payload)
      result = JSON.parse(payload)
      raise WebhookSignatureError, 'failed to parse webhook event: top-level value is not an object' unless result.is_a?(Hash)

      result
    end

    sig do
      params(
        payload: String,
        signature: String,
        secret: String
      ).returns(T::Hash[String, T.untyped])
    end
    def self.verify_and_parse_internal(payload, signature, secret)
      raise WebhookSignatureError, 'invalid webhook signature' unless verify_signature(payload, signature, secret)

      parse_event(payload)
    end
    private_class_method :verify_and_parse_internal

    # Decompress `body` when gzipped, verify the HMAC `signature`, and return
    # the parsed event.
    sig do
      params(
        body: T.any(String, T::Array[Integer]),
        signature: String,
        secret: String
      ).returns(T::Hash[String, T.untyped])
    end
    def self.verify_and_parse_webhook(body, signature, secret)
      verify_and_parse_internal(ungzip_payload(body), signature, secret)
    end

    # Decode the SQS `Body` (base64, then gzip-if-magic), verify the HMAC
    # `signature` from the `X-Signature` message attribute, and return the
    # parsed event.
    sig do
      params(
        message_body: String,
        signature: String,
        secret: String
      ).returns(T::Hash[String, T.untyped])
    end
    def self.verify_and_parse_sqs(message_body, signature, secret)
      verify_and_parse_internal(decode_sqs_payload(message_body), signature, secret)
    end

    # Decode the SNS notification `Message` (identical to SQS handling), verify
    # the HMAC `signature` from the `X-Signature` message attribute, and return
    # the parsed event.
    sig do
      params(
        message: String,
        signature: String,
        secret: String
      ).returns(T::Hash[String, T.untyped])
    end
    def self.verify_and_parse_sns(message, signature, secret)
      verify_and_parse_internal(decode_sns_payload(message), signature, secret)
    end

    # Timing-safe equality check used to compare the locally computed HMAC
    # with the `X-Signature` header. Prefers the OpenSSL primitive when the
    # Ruby build exposes it, otherwise falls back to a manual byte XOR loop
    # that does not short-circuit on the first mismatch.
    sig { params(left: String, right: String).returns(T::Boolean) }
    def self.constant_time_equal?(left, right)
      a = left.b
      b = right.b
      return false unless a.bytesize == b.bytesize

      if OpenSSL.respond_to?(:fixed_length_secure_compare)
        OpenSSL.fixed_length_secure_compare(a, b)
      else
        a_bytes = a.bytes
        b_bytes = b.bytes
        diff = 0
        a_bytes.each_with_index { |byte, i| diff |= byte ^ b_bytes[i] }
        diff.zero?
      end
    end
  end
end
