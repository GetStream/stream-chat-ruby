# typed: strict
# frozen_string_literal: true

require 'base64'
require 'openssl'
require 'sorbet-runtime'
require 'stringio'
require 'zlib'

require 'stream-chat/errors'

module StreamChat
  # Stateless helpers used by the webhook decoding and verification methods on
  # `StreamChat::Client`. Kept in a module so the decode/verify primitives can
  # be exercised in isolation, and so `Client#verify_webhook` (the legacy
  # boolean-returning helper) stays untouched for backward compatibility.
  module Webhook
    extend T::Sig

    SUPPORTED_CONTENT_ENCODINGS = T.let(%w[gzip].freeze, T::Array[String])
    SUPPORTED_PAYLOAD_ENCODINGS = T.let(%w[base64 b64].freeze, T::Array[String])

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

    # Decodes the outer `payload_encoding` wrapper if present. SQS / SNS
    # base64-wrap the gzipped bytes so they remain valid UTF-8 over the queue;
    # plain HTTP webhooks pass `nil` here and this is a no-op.
    sig { params(body: String, payload_encoding: T.nilable(String)).returns(String) }
    def self.apply_payload_encoding(body, payload_encoding)
      normalized = payload_encoding.to_s.strip.downcase
      return body if normalized.empty?

      case normalized
      when 'base64', 'b64'
        decoded =
          begin
            Base64.strict_decode64(body)
          rescue ArgumentError => e
            raise WebhookSignatureError, "failed to decode webhook body using payload_encoding=#{normalized}: #{e.message}"
          end
        String.new(decoded).force_encoding(Encoding::ASCII_8BIT)
      else
        raise WebhookSignatureError, "unsupported webhook payload_encoding: #{normalized}. This SDK only supports base64."
      end
    end

    # Decompresses the payload according to the HTTP `Content-Encoding`
    # header reported by the dashboard / SQS message attribute. `nil` /
    # empty means the body is already the raw JSON document.
    sig { params(body: String, content_encoding: T.nilable(String)).returns(String) }
    def self.apply_content_encoding(body, content_encoding)
      normalized = content_encoding.to_s.strip.downcase
      return body if normalized.empty?

      case normalized
      when 'gzip'
        begin
          inflated = Zlib::GzipReader.new(StringIO.new(body)).read
        rescue Zlib::Error => e
          raise WebhookSignatureError, "failed to decompress webhook body: #{e.message}"
        end
        String.new(inflated).force_encoding(Encoding::ASCII_8BIT)
      else
        raise WebhookSignatureError, %(unsupported webhook Content-Encoding: #{normalized}. This SDK only supports gzip; set webhook_compression_algorithm to "gzip" on the app config.)
      end
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
