# frozen_string_literal: true

require 'stream-chat'

describe StreamChat::Client do
  let(:client) { described_class.new('test-key', 'test-secret') }
  let(:timestamp) { '2026-11-10T00:00:00+00:00' }
  let(:response) { StreamChat::StreamResponse.new({}, Faraday::Response.new(status: 200, response_headers: {})) }

  describe '#revoke_users_token' do
    it 'sends a partial update for each requested user and normalizes the timestamp' do
      updates = %w[alice bob].map do |id|
        { 'id' => id, 'set' => { 'revoke_tokens_issued_before' => timestamp } }
      end
      expect(client).to receive(:patch).with('users', data: { users: updates }).and_return(response)

      expect(client.revoke_users_token(%w[alice bob], DateTime.parse(timestamp))).to equal(response)
    end

    it 'sends an empty update list when no users are requested' do
      expect(client).to receive(:patch).with('users', data: { users: [] }).and_return(response)

      expect(client.revoke_users_token([], timestamp)).to equal(response)
    end
  end

  describe '#revoke_user_token' do
    it 'sends the requested user and preserves a string timestamp' do
      updates = [{ 'id' => 'alice', 'set' => { 'revoke_tokens_issued_before' => timestamp } }]
      expect(client).to receive(:patch).with('users', data: { users: updates }).and_return(response)

      expect(client.revoke_user_token('alice', timestamp)).to equal(response)
    end
  end
end
