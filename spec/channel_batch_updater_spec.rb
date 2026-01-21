# frozen_string_literal: true

require 'securerandom'
require 'stream-chat'

describe StreamChat::ChannelBatchUpdater do
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

  def wait_for_task(task_id, timeout_seconds: 120)
    sleep(2) # Initial delay

    timeout_seconds.times do |i|
      begin
        task = @client.get_task(task_id)
      rescue StandardError => e
        if i < 10
          sleep(1)
          next
        end
        raise e
      end

      expect(task['id']).to eq(task_id)

      case task['status']
      when 'waiting', 'pending', 'running'
        sleep(1)
      when 'completed'
        return task
      when 'failed'
        if task['result']&.dig('description')&.downcase&.include?('rate limit')
          sleep(2)
          next
        end
        raise "Task failed with result: #{task['result']}"
      end
    end

    raise "Task did not complete within #{timeout_seconds} seconds"
  end

  before(:all) do
    @client = StreamChat::Client.from_env
    @created_users = []
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid, name: 'user1' }, { id: SecureRandom.uuid, name: 'user2' }]
    @random_user = { id: SecureRandom.uuid }

    users_to_insert = [@random_users[0], @random_users[1], @random_user]

    @created_users.push(*users_to_insert.map { |u| u[:id] })
    @client.upsert_users(users_to_insert)

    @channel1 = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true })
    @channel1.create(@random_user[:id])

    @channel2 = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true })
    @channel2.create(@random_user[:id])
  end

  after(:each) do
    @channel1&.delete
  rescue StreamChat::StreamAPIException
    # Ignore if channel already deleted
  ensure
    begin
      @channel2&.delete
    rescue StreamChat::StreamAPIException
      # Ignore if channel already deleted
    end
  end

  after(:all) do
    curr_idx = 0
    batch_size = 25

    slice = @created_users.slice(0, batch_size)

    while !slice.nil? && !slice.empty?
      @client.delete_users(slice, user: StreamChat::HARD_DELETE, messages: StreamChat::HARD_DELETE)

      curr_idx += batch_size
      slice = @created_users.slice(curr_idx, batch_size)
    end
  end

  describe 'Client#update_channels_batch' do
    it 'returns error if options is empty' do
      expect { @client.update_channels_batch({}) }.to raise_error(StreamChat::StreamAPIException)
    end

    it 'batch updates channels with valid options' do
      response = @client.update_channels_batch(
        {
          operation: 'addMembers',
          filter: { cid: { '$in' => [@channel1.cid, @channel2.cid] } },
          members: [@random_users[0][:id]]
        }
      )

      expect(response['task_id']).not_to be_empty
    end
  end

  describe 'ChannelBatchUpdater#add_members' do
    it 'adds members to channels matching filter' do
      updater = @client.channel_batch_updater

      members = @random_users.map { |u| u[:id] }
      response = updater.add_members(
        { cid: { '$in' => [@channel1.cid, @channel2.cid] } },
        members
      )

      expect(response['task_id']).not_to be_empty
      task_id = response['task_id']

      wait_for_task(task_id)

      # Verify members were added
      loop_times(120) do
        ch1_state = @channel1.query
        ch1_member_ids = ch1_state['members'].map { |m| m['user_id'] }

        members.each do |member_id|
          expect(ch1_member_ids).to include(member_id)
        end
      end
    end
  end

  describe 'ChannelBatchUpdater#remove_members' do
    it 'removes members from channels matching filter' do
      # First add both users as members to both channels
      members_to_add = @random_users.map { |u| u[:id] }
      @channel1.add_members(members_to_add)
      @channel2.add_members(members_to_add)

      # Verify members were added
      loop_times(60) do
        ch1_state = @channel1.query
        expect(ch1_state['members'].length).to eq(2)

        ch2_state = @channel2.query
        expect(ch2_state['members'].length).to eq(2)
      end

      # Verify member IDs match
      ch1_state = @channel1.query
      ch1_member_ids = ch1_state['members'].map { |m| m['user_id'] }
      expect(ch1_member_ids).to match_array(members_to_add)

      ch2_state = @channel2.query
      ch2_member_ids = ch2_state['members'].map { |m| m['user_id'] }
      expect(ch2_member_ids).to match_array(members_to_add)

      # Now remove one member using batch updater
      updater = @client.channel_batch_updater
      member_to_remove = members_to_add[0]

      response = updater.remove_members(
        { cid: { '$in' => [@channel1.cid, @channel2.cid] } },
        [member_to_remove]
      )

      expect(response['task_id']).not_to be_empty
      task_id = response['task_id']

      wait_for_task(task_id)

      # Verify member was removed
      loop_times(120) do
        ch1_state = @channel1.query
        ch1_member_ids = ch1_state['members'].map { |m| m['user_id'] }

        expect(ch1_member_ids).not_to include(member_to_remove)
      end
    end
  end

  describe 'ChannelBatchUpdater#archive' do
    it 'archives channels for specified members' do
      # First add both users as members to both channels
      members_to_add = @random_users.map { |u| u[:id] }
      @channel1.add_members(members_to_add)
      @channel2.add_members(members_to_add)

      # Wait for members to be added
      loop_times(60) do
        ch1_state = @channel1.query
        expect(ch1_state['members'].length).to eq(2)
      end

      # Archive channels for one member
      updater = @client.channel_batch_updater
      member_to_archive = members_to_add[0]

      response = updater.archive(
        { cid: { '$in' => [@channel1.cid, @channel2.cid] } },
        [member_to_archive]
      )

      expect(response['task_id']).not_to be_empty
      task_id = response['task_id']

      wait_for_task(task_id)

      # Verify archived_at is set for the member
      loop_times(120) do
        ch1_state = @channel1.query
        member = ch1_state['members'].find { |m| m['user_id'] == member_to_archive }

        expect(member).not_to be_nil
        expect(member['archived_at']).not_to be_nil
      end
    end
  end
end
