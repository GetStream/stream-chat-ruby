# frozen_string_literal: true

require 'jwt'
require 'securerandom'
require 'stream-chat'
require 'faraday'

describe StreamChat::Moderation do
  def loop_times(times)
    loop do
      begin
        yield()
        return
      rescue StandardError, RSpec::Expectations::ExpectationNotMetError
        raise if times.zero?
      end

      sleep(1)
      times -= 1
    end
  end

  before(:all) do
    @client = StreamChat::Client.from_env

    @created_users = []

    @fellowship_of_the_ring = [
      { id: SecureRandom.uuid, name: 'Frodo Baggins', race: 'Hobbit', age: 50 },
      { id: SecureRandom.uuid, name: 'Samwise Gamgee', race: 'Hobbit', age: 38 },
      { id: SecureRandom.uuid, name: 'Gandalf the Grey', race: 'Istari' },
      { id: SecureRandom.uuid, name: 'Legolas', race: 'Elf', age: 500 }
    ]
    @gandalf = @fellowship_of_the_ring[2]
    @frodo = @fellowship_of_the_ring[0]
    @sam = @fellowship_of_the_ring[1]
    @legolas = @fellowship_of_the_ring[3]

    @client.upsert_users(@fellowship_of_the_ring)

    # Create a new channel for moderation
    channel_id = "fellowship-of-the-ring-moderation-#{SecureRandom.alphanumeric(20)}"

    @channel = @client.channel('team', channel_id: channel_id,
                                       data: { members: @fellowship_of_the_ring.map { |fellow| fellow[:id] } })
    @channel.create(@fellowship_of_the_ring[2][:id])
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid }, { id: SecureRandom.uuid }, { id: SecureRandom.uuid }]
    @random_user = @random_users[0]

    @created_users.push(*@random_users.map { |u| u[:id] })

    @client.upsert_users(@random_users)
  end

  after(:all) do
    @channel.delete

    curr_idx = 0
    batch_size = 25

    @users_to_delete = @created_users.dup + @fellowship_of_the_ring.map { |fellow| fellow[:id] }

    slice = @users_to_delete.slice(0, batch_size)

    while !slice.nil? && !slice.empty?
      @client.delete_users(slice, user: StreamChat::HARD_DELETE, messages: StreamChat::HARD_DELETE)

      curr_idx += batch_size
      slice = @users_to_delete.slice(curr_idx, batch_size)
    end
  end

  it 'properly sets up a new client' do
    client = StreamChat::Client.from_env

    client.set_http_client(Faraday.new(url: 'https://getstream.io'))
    expect { client.get_app_settings }.to raise_error(StreamChat::StreamAPIException)

    client.set_http_client(Faraday.new(url: 'https://chat.stream-io-api.com'))
    response = client.get_app_settings
    expect(response).to include 'app'
  end

  it 'raises ArgumentError if no api_key is provided' do
    expect { StreamChat::Client.new(nil, nil) }.to raise_error(TypeError)
  end

  it 'properly handles stream response class' do
    response = @client.get_app_settings
    expect(response.rate_limit.limit).to be > 0
    expect(response.rate_limit.remaining).to be > 0
    expect(response.rate_limit.reset).to be_within(120).of Time.now.utc
    expect(response.status_code).to be 200
    expect(response.to_json).not_to include 'rate_limit'
    expect(response.to_json).not_to include 'status_code'
  end

  describe 'moderation' do
    before(:each) do
      @moderation = @client.moderation
      @test_user_id = SecureRandom.uuid
      @test_message_id = SecureRandom.uuid
      @test_config_key = SecureRandom.uuid
    end

    it 'flagging a user and message' do
      msg_response = @channel.send_message({ id: @test_message_id, text: 'Test message' }, @test_user_id)
      expect(msg_response['message']['id']).to eq(@test_message_id)
      expect(msg_response['message']['user']['id']).to eq(@test_user_id)
      response = @moderation.flag_user(
        @test_user_id,
        'inappropriate_behavior',
        user_id: @random_user[:id],
        custom: { severity: 'high' }
      )
      expect(response['duration']).not_to be_nil
      response = @moderation.flag_message(
        @test_message_id,
        'inappropriate_content',
        user_id: @random_user[:id],
        custom: { category: 'spam' }
      )
      expect(response['duration']).not_to be_nil
    end

    it 'mute a user and unmute a user' do
      @channel.send_message({ id: @test_message_id, text: 'Test message' }, @test_user_id)
      testuserid1 = @random_user[:id]
      response = @moderation.mute_user(
        @test_user_id,
        user_id: testuserid1,
        timeout: 60
      )
      expect(response['duration']).not_to be_nil
      expect(response['mutes'][0]['user']['id']).to eq(testuserid1)
      response = @moderation.unmute_user(
        @test_user_id,
        user_id: @random_user[:id]
      )
      expect(response['duration']).not_to be_nil

      response = @moderation.get_user_moderation_report(
        @test_user_id,
        include_user_blocks: true,
        include_user_mutes: true
      )
      expect(response['duration']).not_to be_nil
    end

    it 'adds custom flags to an entity' do
      testuserid1 = @random_user[:id]
      testmsgid1 = SecureRandom.uuid
      @channel.send_message({ id: testmsgid1, text: 'Test message' }, testuserid1)
      entity_type = 'stream:chat:v1:message'
      entity_id = testmsgid1
      moderation_payload = {
        'texts' => ['Test message'],
        'custom' => { 'original_message_type' => 'regular' }
      }
      flags = [{ type: 'custom_check_text', value: 'test_flag' }]

      response = @moderation.add_custom_flags(entity_type, entity_id, moderation_payload, flags, entity_creator_id: testuserid1)
      expect(response['duration']).not_to be_nil
      response = @moderation.add_custom_message_flags(
        testmsgid1,
        [{ type: 'custom_check_text', value: 'test_flag' }]
      )
      expect(response['duration']).not_to be_nil
    end

    it 'check user profile' do
      response = @moderation.check_user_profile(
        @test_user_id,
        { username: 'fuck_you_123' }
      )
      expect(response['duration']).not_to be_nil
      expect(response['status']).to eq('complete')
      expect(response['recommended_action']).to eq('remove')

      response = @moderation.check_user_profile(
        @test_user_id,
        { username: 'hi' }
      )
      expect(response['duration']).not_to be_nil
      expect(response['status']).to eq('complete')
      expect(response['recommended_action']).to eq('keep')
    end

    it 'config test' do
      # Create moderation config
      moderation_config = {
        key: "chat:team:#{@channel.id}",
        block_list_config: {
          enabled: true,
          rules: [
            {
              name: 'profanity_en_2020_v1',
              action: 'flag'
            }
          ]
        }
      }
      @moderation.upsert_config(moderation_config)
      response = @moderation.get_config("chat:team:#{@channel.id}")
      expect(response['config']['key']).to eq("chat:team:#{@channel.id}")

      response = @moderation.query_configs(
        { key: "chat:messaging:#{@channel.id}" },
        []
      )
      expect(response).not_to be_nil

      # Send message that should be blocked
      response = @channel.send_message(
        { text: 'damn' },
        @random_user[:id],
        force_moderation: true
      )

      # Verify message appears in review queue
      queue_response = @moderation.query_review_queue(
        { entity_type: 'stream:chat:v1:message' },
        { created_at: -1 },
        limit: 1
      )
      expect(queue_response['items'][0]['entity_id']).to eq(response['message']['id'])

      response = @moderation.delete_config("chat:team:#{@channel.id}")
      expect(response['duration']).not_to be_nil
    end
  end
end
