# frozen_string_literal: true

require 'stream-chat'
require 'faraday'
require 'securerandom'

describe StreamChat::Thread do
  before(:all) do
    @client = StreamChat::Client.from_env
    @created_users = []
  end

  before(:each) do
    @random_user = { id: SecureRandom.uuid }
    @created_users.push(@random_user[:id])
    @client.upsert_users([@random_user])
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

  describe '#query_threads' do
    it 'queries threads with filter' do
      # Create a channel and send a message to create a thread
      channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true })
      channel.create(@random_user[:id])

      # Send a message to create a thread
      message = channel.send_message({ text: 'Thread parent message' }, @random_user[:id])

      # Send a reply to create a thread
      channel.send_message({ text: 'Thread reply', parent_id: message['message']['id'] }, @random_user[:id])

      # Query threads with filter
      filter = {
        'created_by_user_id' => { '$eq' => @random_user[:id] }
      }

      response = @client.thread.query_threads(filter, user_id: @random_user[:id])

      # Verify the response
      expect(response).to include 'threads'
      expect(response['threads'].length).to be >= 1

      # Clean up
      channel.delete
    end

    it 'queries threads with sort' do
      # Create a channel and send a message to create a thread
      channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true })
      channel.create(@random_user[:id])

      # Send a message to create a thread
      message = channel.send_message({ text: 'Thread parent message' }, @random_user[:id])

      # Send a reply to create a thread
      channel.send_message({ text: 'Thread reply', parent_id: message['message']['id'] }, @random_user[:id])

      # Query threads with sort
      sort = {
        'created_at' => -1
      }

      response = @client.thread.query_threads(sort: sort, user_id: @random_user[:id])

      # Verify the response
      expect(response).to include 'threads'
      expect(response['threads'].length).to be >= 1

      # Clean up
      channel.delete
    end

    it 'queries threads with both filter and sort' do
      # Create a channel and send a message to create a thread
      channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true })
      channel.create(@random_user[:id])

      # Send a message to create a thread
      message = channel.send_message({ text: 'Thread parent message' }, @random_user[:id])

      # Send a reply to create a thread
      channel.send_message({ text: 'Thread reply', parent_id: message['message']['id'] }, @random_user[:id])

      # Query threads with both filter and sort
      filter = {
        'created_by_user_id' => { '$eq' => @random_user[:id] }
      }

      sort = {
        'created_at' => -1
      }

      response = @client.thread.query_threads(filter, sort: sort, user_id: @random_user[:id])

      # Verify the response
      expect(response).to include 'threads'
      expect(response['threads'].length).to be >= 1

      # Clean up
      channel.delete
    end
  end
end
