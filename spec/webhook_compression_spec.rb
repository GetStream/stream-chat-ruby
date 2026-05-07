# frozen_string_literal: true

require 'base64'
require 'openssl'
require 'stringio'
require 'zlib'

require 'stream-chat'

describe 'StreamChat webhook compression' do
  let(:json_body) { '{"type":"message.new","message":{"text":"the quick brown fox"}}' }
  let(:api_key)    { 'tkey' }
  let(:api_secret) { 'tsec2' }

  def gzip(bytes)
    io = StringIO.new
    io.set_encoding(Encoding::ASCII_8BIT)
    Zlib::GzipWriter.wrap(io) { |gz| gz.write(bytes) }
    io.string
  end

  def hmac_hex(secret, data)
    OpenSSL::HMAC.hexdigest('SHA256', secret, data)
  end

  let(:client) { StreamChat::Client.new(api_key, api_secret) }

  describe '#verify_webhook (existing helper, must remain backwards compatible)' do
    it 'returns true when the signature matches the raw body' do
      signature = hmac_hex(api_secret, json_body)
      expect(client.verify_webhook(json_body, signature)).to be true
    end

    it 'returns false when the signature does not match' do
      expect(client.verify_webhook(json_body, 'not-a-real-signature')).to be false
    end
  end

  describe '#decompress_webhook_body' do
    context 'when both encodings are nil or empty' do
      it 'returns the body unchanged when encodings are nil' do
        expect(client.decompress_webhook_body(json_body, nil, nil)).to eq(json_body)
      end

      it 'returns the body unchanged when encodings are empty strings' do
        expect(client.decompress_webhook_body(json_body, '', '')).to eq(json_body)
      end

      it 'returns the body unchanged when encodings are whitespace' do
        expect(client.decompress_webhook_body(json_body, '   ', '   ')).to eq(json_body)
      end

      it 'accepts a body provided as an array of integers (byte array)' do
        bytes = json_body.bytes
        expect(client.decompress_webhook_body(bytes, nil, nil)).to eq(json_body)
      end
    end

    context 'gzip round-trip' do
      it 'decompresses a gzip-compressed body' do
        compressed = gzip(json_body)
        expect(client.decompress_webhook_body(compressed, 'gzip', nil)).to eq(json_body)
      end

      it 'is case-insensitive for the content_encoding value' do
        compressed = gzip(json_body)
        expect(client.decompress_webhook_body(compressed, 'GZIP', nil)).to eq(json_body)
        expect(client.decompress_webhook_body(compressed, '  Gzip  ', nil)).to eq(json_body)
      end
    end

    context 'base64 round-trip' do
      it 'decodes a strict-base64 wrapped body' do
        wrapped = Base64.strict_encode64(json_body)
        expect(client.decompress_webhook_body(wrapped, nil, 'base64')).to eq(json_body)
      end

      it 'accepts the b64 alias' do
        wrapped = Base64.strict_encode64(json_body)
        expect(client.decompress_webhook_body(wrapped, nil, 'b64')).to eq(json_body)
      end

      it 'is case-insensitive for the payload_encoding value' do
        wrapped = Base64.strict_encode64(json_body)
        expect(client.decompress_webhook_body(wrapped, nil, 'BASE64')).to eq(json_body)
        expect(client.decompress_webhook_body(wrapped, nil, '  Base64  ')).to eq(json_body)
      end
    end

    context 'base64 + gzip round-trip (SQS / SNS firehose shape)' do
      it 'decodes the base64 wrapper and then decompresses the gzip body' do
        wrapped = Base64.strict_encode64(gzip(json_body))
        expect(client.decompress_webhook_body(wrapped, 'gzip', 'base64')).to eq(json_body)
      end
    end

    context 'unsupported encodings' do
      %w[br brotli zstd deflate compress lz4].each do |unsupported|
        it "rejects content_encoding=#{unsupported.inspect}" do
          expect { client.decompress_webhook_body(json_body, unsupported, nil) }
            .to raise_error(StreamChat::WebhookSignatureError, /unsupported webhook Content-Encoding/i)
        end
      end

      %w[hex url binary].each do |unsupported|
        it "rejects payload_encoding=#{unsupported.inspect}" do
          expect { client.decompress_webhook_body(json_body, nil, unsupported) }
            .to raise_error(StreamChat::WebhookSignatureError, /unsupported webhook payload_encoding/i)
        end
      end
    end

    context 'malformed payloads' do
      it 'raises when the gzip bytes are corrupt' do
        expect { client.decompress_webhook_body('not-actually-gzip', 'gzip', nil) }
          .to raise_error(StreamChat::WebhookSignatureError, /failed to decompress webhook body/i)
      end

      it 'raises on invalid base64 input' do
        expect { client.decompress_webhook_body("\x00\x01\xff not base64", nil, 'base64') }
          .to raise_error(StreamChat::WebhookSignatureError, /payload_encoding=base64/i)
      end
    end
  end

  describe '#verify_and_decode_webhook' do
    context 'happy paths' do
      it 'verifies and returns the body for a plain HTTP webhook' do
        signature = hmac_hex(api_secret, json_body)
        expect(client.verify_and_decode_webhook(json_body, signature, nil, nil)).to eq(json_body)
      end

      it 'verifies and returns the body for a gzip-compressed webhook (signature over uncompressed bytes)' do
        compressed = gzip(json_body)
        signature = hmac_hex(api_secret, json_body)
        expect(client.verify_and_decode_webhook(compressed, signature, 'gzip', nil)).to eq(json_body)
      end

      it 'verifies and returns the body for a base64+gzip SQS / SNS webhook (signature over uncompressed bytes)' do
        wrapped = Base64.strict_encode64(gzip(json_body))
        signature = hmac_hex(api_secret, json_body)
        expect(client.verify_and_decode_webhook(wrapped, signature, 'gzip', 'base64')).to eq(json_body)
      end
    end

    context 'signature mismatches' do
      it 'raises WebhookSignatureError when the signature is wrong' do
        expect { client.verify_and_decode_webhook(json_body, 'definitely-wrong', nil, nil) }
          .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
      end

      it 'rejects a gzip body when the signature was computed over the compressed bytes (not the JSON)' do
        compressed = gzip(json_body)
        wrong_signature_over_compressed = hmac_hex(api_secret, compressed)
        expect { client.verify_and_decode_webhook(compressed, wrong_signature_over_compressed, 'gzip', nil) }
          .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
      end

      it 'rejects a base64+gzip body when the signature was computed over the wrapped bytes (not the JSON)' do
        wrapped = Base64.strict_encode64(gzip(json_body))
        wrong_signature_over_wrapped = hmac_hex(api_secret, wrapped)
        expect { client.verify_and_decode_webhook(wrapped, wrong_signature_over_wrapped, 'gzip', 'base64') }
          .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
      end
    end
  end
end
