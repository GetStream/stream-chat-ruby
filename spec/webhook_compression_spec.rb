# frozen_string_literal: true

require 'base64'
require 'json'
require 'openssl'
require 'stringio'
require 'zlib'

require 'stream-chat'

describe 'StreamChat webhook verification + parsing' do
  let(:json_body) { '{"type":"message.new","message":{"text":"the quick brown fox"}}' }
  let(:event_hash) { { 'type' => 'message.new', 'message' => { 'text' => 'the quick brown fox' } } }
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

  def sns_envelope(inner_message)
    JSON.generate({
                    'Type' => 'Notification',
                    'MessageId' => '22b80b92-fdea-4c2c-8f9d-bdfb0c7bf324',
                    'TopicArn' => 'arn:aws:sns:us-east-1:123456789012:stream-webhooks',
                    'Message' => inner_message,
                    'Timestamp' => '2026-05-11T10:00:00.000Z',
                    'SignatureVersion' => '1',
                    'MessageAttributes' => {
                      'X-Signature' => { 'Type' => 'String', 'Value' => '<signature placeholder>' }
                    }
                  })
  end

  let(:client) { StreamChat::Client.new(api_key, api_secret) }

  describe 'StreamChat::Webhook.ungzip_payload' do
    it 'passes through plain bytes unchanged' do
      expect(StreamChat::Webhook.ungzip_payload(json_body)).to eq(json_body)
    end

    it 'inflates gzip-magic bytes' do
      expect(StreamChat::Webhook.ungzip_payload(gzip(json_body))).to eq(json_body)
    end

    it 'accepts a body provided as an array of integers' do
      expect(StreamChat::Webhook.ungzip_payload(json_body.bytes)).to eq(json_body)
    end

    it 'returns empty input unchanged' do
      expect(StreamChat::Webhook.ungzip_payload('')).to eq('')
    end

    it 'returns short input below magic length unchanged' do
      expect(StreamChat::Webhook.ungzip_payload('ab')).to eq('ab')
    end

    it 'raises on truncated gzip with magic' do
      bad = "\x1f\x8b\x08\x00\x00\x00".b
      expect { StreamChat::Webhook.ungzip_payload(bad) }
        .to raise_error(StreamChat::WebhookSignatureError, /decompress gzip/i)
    end
  end

  describe 'StreamChat::Webhook.decode_sqs_payload' do
    it 'decodes base64 only (no compression)' do
      wrapped = Base64.strict_encode64(json_body)
      expect(StreamChat::Webhook.decode_sqs_payload(wrapped)).to eq(json_body)
    end

    it 'decodes base64 + gzip' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      expect(StreamChat::Webhook.decode_sqs_payload(wrapped)).to eq(json_body)
    end

    it 'raises on invalid base64' do
      expect { StreamChat::Webhook.decode_sqs_payload('!!!not-base64!!!') }
        .to raise_error(StreamChat::WebhookSignatureError, /base64-decode/i)
    end
  end

  describe 'StreamChat::Webhook.decode_sns_payload' do
    it 'treats a pre-extracted Message identically to decode_sqs_payload' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      expect(StreamChat::Webhook.decode_sns_payload(wrapped))
        .to eq(StreamChat::Webhook.decode_sqs_payload(wrapped))
    end

    it 'unwraps a full SNS HTTP notification envelope' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      envelope = sns_envelope(wrapped)
      expect(StreamChat::Webhook.decode_sns_payload(envelope)).to eq(json_body)
    end

    it 'handles whitespace before the envelope JSON' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      envelope = "\n  #{sns_envelope(wrapped)}"
      expect(StreamChat::Webhook.decode_sns_payload(envelope)).to eq(json_body)
    end
  end

  describe 'StreamChat::Webhook.verify_signature' do
    it 'returns true for matching HMAC' do
      sig = hmac_hex(api_secret, json_body)
      expect(StreamChat::Webhook.verify_signature(json_body, sig, api_secret)).to be true
    end

    it 'returns false for mismatched signature' do
      expect(StreamChat::Webhook.verify_signature(json_body, '0' * 64, api_secret)).to be false
    end

    it 'rejects signatures computed over compressed bytes' do
      compressed = gzip(json_body)
      sig_over_compressed = hmac_hex(api_secret, compressed)
      expect(StreamChat::Webhook.verify_signature(json_body, sig_over_compressed, api_secret)).to be false
    end
  end

  describe 'StreamChat::Webhook.parse_event' do
    it 'parses a known event type into a hash' do
      expect(StreamChat::Webhook.parse_event(json_body)).to eq(event_hash)
    end

    it 'still parses unknown event types' do
      expect(StreamChat::Webhook.parse_event('{"type":"a.future.event","custom":42}'))
        .to eq({ 'type' => 'a.future.event', 'custom' => 42 })
    end

    it 'raises on malformed JSON' do
      expect { StreamChat::Webhook.parse_event('not json') }.to raise_error(JSON::ParserError)
    end
  end

  describe '#verify_webhook (legacy boolean helper, unchanged)' do
    it 'returns true when the signature matches the raw body' do
      expect(client.verify_webhook(json_body, hmac_hex(api_secret, json_body))).to be true
    end

    it 'returns false when the signature does not match' do
      expect(client.verify_webhook(json_body, 'not-a-real-signature')).to be false
    end
  end

  describe '#verify_and_parse_webhook' do
    it 'parses a plain JSON body with a valid signature' do
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_webhook(json_body, sig)).to eq(event_hash)
    end

    it 'parses a gzip-compressed body' do
      compressed = gzip(json_body)
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_webhook(compressed, sig)).to eq(event_hash)
    end

    it 'accepts a body provided as an array of integers' do
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_webhook(json_body.bytes, sig)).to eq(event_hash)
    end

    it 'raises WebhookSignatureError on signature mismatch' do
      expect { client.verify_and_parse_webhook(json_body, 'definitely-wrong') }
        .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
    end

    it 'rejects a gzip body when the signature was computed over compressed bytes' do
      compressed = gzip(json_body)
      sig_over_compressed = hmac_hex(api_secret, compressed)
      expect { client.verify_and_parse_webhook(compressed, sig_over_compressed) }
        .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
    end
  end

  describe '#verify_and_parse_sqs' do
    it 'parses a base64-only message body' do
      wrapped = Base64.strict_encode64(json_body)
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_sqs(wrapped, sig)).to eq(event_hash)
    end

    it 'parses a base64 + gzip message body' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_sqs(wrapped, sig)).to eq(event_hash)
    end

    it 'rejects a wrapped body when the signature was computed over the wrapper' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      sig_over_wrapped = hmac_hex(api_secret, wrapped)
      expect { client.verify_and_parse_sqs(wrapped, sig_over_wrapped) }
        .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
    end
  end

  describe '#verify_and_parse_sns' do
    it 'parses a pre-extracted base64 + gzip notification' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_sns(wrapped, sig)).to eq(event_hash)
    end

    it 'returns the same event as verify_and_parse_sqs for pre-extracted Message' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_sns(wrapped, sig))
        .to eq(client.verify_and_parse_sqs(wrapped, sig))
    end

    it 'parses a full SNS HTTP notification envelope' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      envelope = sns_envelope(wrapped)
      sig = hmac_hex(api_secret, json_body)
      expect(client.verify_and_parse_sns(envelope, sig)).to eq(event_hash)
    end

    it 'rejects signature computed over the envelope JSON, not the payload' do
      wrapped = Base64.strict_encode64(gzip(json_body))
      envelope = sns_envelope(wrapped)
      sig_over_envelope = hmac_hex(api_secret, envelope)
      expect { client.verify_and_parse_sns(envelope, sig_over_envelope) }
        .to raise_error(StreamChat::WebhookSignatureError, 'invalid webhook signature')
    end
  end
end
