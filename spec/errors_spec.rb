# typed: false
# frozen_string_literal: true

require 'stream-chat'

describe StreamChat::StreamAPIException do
  def response_with(status, body)
    Faraday::Response.new(Faraday::Env.from(status: status, body: body))
  end

  context 'with a well-formed JSON error body' do
    subject(:exception) do
      described_class.new(response_with(429, { code: 9, message: 'rate limit' }.to_json))
    end

    it 'exposes the integer code and message' do
      expect(exception.json_response).to be true
      expect(exception.error_code).to eq(9)
      expect(exception.error_message).to eq('rate limit')
      expect(exception.message).to eq('StreamChat error code 9: rate limit')
    end
  end

  context 'with a 503 and an empty body' do
    subject(:exception) { described_class.new(response_with(503, '')) }

    it 'does not raise when the typed readers are accessed' do
      expect(exception.json_response).to be false
      expect(exception.error_code).to eq(-1)
      expect(exception.error_message).to eq('unknown')
    end

    it 'falls back to the HTTP status in the message' do
      expect(exception.message).to eq('StreamChat error HTTP code: 503')
    end
  end

  context 'with a non-JSON body' do
    subject(:exception) { described_class.new(response_with(502, '<html>502 Bad Gateway</html>')) }

    it 'falls back to defaults and the HTTP status' do
      expect(exception.json_response).to be false
      expect(exception.error_code).to eq(-1)
      expect(exception.message).to eq('StreamChat error HTTP code: 502')
    end
  end

  context 'with a non-integer code (edge rate-limit envelope)' do
    subject(:exception) do
      described_class.new(response_with(429, { code: 'rate_limit_exceeded', message: 'slow down' }.to_json))
    end

    it 'keeps the sentinel code rather than raising a TypeError' do
      expect(exception.json_response).to be true
      expect(exception.error_code).to eq(-1)
      expect(exception.error_message).to eq('slow down')
    end
  end

  context 'with a JSON body missing code and message' do
    subject(:exception) { described_class.new(response_with(500, {}.to_json)) }

    it 'returns the default code and message' do
      expect(exception.error_code).to eq(-1)
      expect(exception.error_message).to eq('unknown')
    end
  end
end
