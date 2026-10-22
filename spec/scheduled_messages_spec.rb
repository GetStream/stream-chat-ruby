# typed: false
# frozen_string_literal: true

require 'json'
require 'stream-chat'

# Request-shape tests for the scheduled message methods. They run against a
# stubbed HTTP adapter, so they need no Stream credentials; the round trip
# against a live app is covered in client_spec.rb.
describe 'scheduled messages requests' do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:request_bodies) { [] }
  let(:client) do
    client = StreamChat::Client.new('key', 'secret')
    client.set_http_client(Faraday.new(url: 'https://chat.stream-io-api.com') { |f| f.adapter :test, stubs })
    client
  end
  let(:response_body) { { scheduled_message: { id: 'sm-1' } }.to_json }

  def stub_request(method, path)
    stubs.public_send(method, path) do |env|
      request_bodies << env.body
      [200, { 'Content-Type' => 'application/json' }, response_body]
    end
  end

  def sent_body
    JSON.parse(request_bodies.last)
  end

  after { stubs.verify_stubbed_calls }

  it 'schedule_message sends the message with scheduled_at' do
    stub_request(:post, '/channels/messaging/general/message')
    scheduled_at = Time.utc(2030, 1, 2, 3, 4, 5)

    response = client.channel('messaging', channel_id: 'general')
                     .schedule_message({ text: 'later' }, 'jane', scheduled_at, skip_push: true)

    expect(response['scheduled_message']['id']).to eq('sm-1')
    expect(sent_body).to eq(
      'message' => { 'text' => 'later', 'user' => { 'id' => 'jane' } },
      'scheduled_at' => '2030-01-02T03:04:05Z',
      'skip_push' => true
    )
  end

  it 'update_scheduled_message patches message and scheduled_at' do
    stub_request(:patch, '/scheduled_messages/sm-1')

    client.update_scheduled_message('sm-1', message: { text: 'edited' }, scheduled_at: '2030-01-02T03:04:05Z')

    expect(sent_body).to eq(
      'message' => { 'text' => 'edited' },
      'scheduled_at' => '2030-01-02T03:04:05Z'
    )
  end

  it 'update_scheduled_message sends only the fields given' do
    stub_request(:patch, '/scheduled_messages/sm-1')

    client.update_scheduled_message('sm-1', scheduled_at: DateTime.new(2030, 1, 2, 3, 4, 5))

    expect(sent_body).to eq('scheduled_at' => '2030-01-02T03:04:05+00:00')
  end

  it 'delete_scheduled_message deletes by id' do
    stub_request(:delete, '/scheduled_messages/sm-1')

    response = client.delete_scheduled_message('sm-1')

    expect(response['scheduled_message']['id']).to eq('sm-1')
  end

  it 'send_scheduled_message_now posts to send_now' do
    stub_request(:post, '/scheduled_messages/sm-1/send_now')

    response = client.send_scheduled_message_now('sm-1')

    expect(response['scheduled_message']['id']).to eq('sm-1')
  end

  it 'query_scheduled_messages sends user_id, filter, sort and pagination' do
    stub_request(:post, '/scheduled_messages/query')

    client.query_scheduled_messages(
      'jane',
      filter: { cid: 'messaging:general', status: %w[scheduled failed] },
      sort: [{ field: 'scheduled_at', direction: 1 }],
      limit: 10,
      next: 'cursor'
    )

    expect(sent_body).to eq(
      'user_id' => 'jane',
      'filter' => { 'cid' => 'messaging:general', 'status' => %w[scheduled failed] },
      'sort' => [{ 'field' => 'scheduled_at', 'direction' => 1 }],
      'limit' => 10,
      'next' => 'cursor'
    )
  end
end
