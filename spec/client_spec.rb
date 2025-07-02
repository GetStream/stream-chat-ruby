# frozen_string_literal: true

require 'jwt'
require 'securerandom'
require 'stream-chat'
require 'faraday'

describe StreamChat::Client do
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

    @legolas = @fellowship_of_the_ring[3][:id]
    @gandalf = @fellowship_of_the_ring[2][:id]
    @frodo = @fellowship_of_the_ring[0][:id]
    @sam = @fellowship_of_the_ring[1][:id]

    @client.upsert_users(@fellowship_of_the_ring)

    # Create a new channel for chat max length for channel_id is 64 characters
    channel_id = "fellowship-of-the-ring-chat-#{SecureRandom.alphanumeric(20)}"

    @channel = @client.channel('team', channel_id: channel_id,
                                       data: { members: @fellowship_of_the_ring.map { |fellow| fellow[:id] } })
    @channel.create(@gandalf)
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid }, { id: SecureRandom.uuid }, { id: SecureRandom.uuid }]
    @random_user = @random_users[0]

    @created_users.push(*@random_users.map { |u| u[:id] })

    @client.upsert_users(@random_users)
  end

  after(:all) do
    @channel.delete

    @users_to_delete = @created_users.dup + @fellowship_of_the_ring.map { |fellow| fellow[:id] }
    curr_idx = 0
    batch_size = 25

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

  it 'mutes users' do
    response = @client.mute_user(@random_users[0][:id], @random_users[1][:id])
    expect(response).to include 'mute'
    expect(response['mute']['target']['id']).to eq(@random_users[0][:id])
    expect(response['mute']['user']['id']).to eq(@random_users[1][:id])
    @client.unmute_user(@random_users[0][:id], @random_users[1][:id])
  end

  it 'retrieves a channel type' do
    response = @client.get_channel_type('team')
    expect(response).to include 'permissions'
  end

  it 'lists channel types' do
    response = @client.list_channel_types
    expect(response).to include 'channel_types'
  end

  it 'creates a user token' do
    token = @client.create_token('tommaso')
    payload = JWT.decode(token, @client.api_secret)
    expect(payload[0].fetch('user_id')).to eq 'tommaso'
  end

  it 'retrieves application settings' do
    response = @client.get_app_settings
    expect(response).to include 'app'
  end

  it 'updates application settings' do
    response = @client.update_app_settings(enforce_unique_usernames: 'no')
    expect(response.status_code).to be 200
  end

  it 'updates a user' do
    user = { id: SecureRandom.uuid }
    response = @client.update_user(user)
    expect(response).to include 'users'
    expect(response['users']).to include user[:id]
  end

  it 'creates a user with team and teams_role' do
    user = {
      id: SecureRandom.uuid,
      team: 'blue',
      teams_role: { 'blue' => 'admin' }
    }
    response = @client.update_user(user)
    expect(response).to include 'users'
    expect(response['users']).to include user[:id]
    expect(response['users'][user[:id]]['team']).to eq 'blue'
    expect(response['users'][user[:id]]['teams_role']['blue']).to eq 'admin'
  end

  it 'updates multiple users' do
    users = [{ id: SecureRandom.uuid }, { id: SecureRandom.uuid }]
    response = @client.update_users(users)
    expect(response).to include 'users'
    expect(response['users']).to include users[0][:id]
  end

  it 'raises when a user without an id is provided' do
    users = [{}, {}]
    expect { @client.update_users(users) }.to raise_error(ArgumentError)
  end

  it 'makes partial user update' do
    user_id = SecureRandom.uuid
    @client.update_user({ id: user_id, field: 'value' })

    response = @client.update_user_partial({
                                             id: user_id,
                                             set: { field: 'updated' }
                                           })

    expect(response['users'][user_id]['field']).to eq('updated')
  end

  it 'makes partial user update with team and teams_role' do
    user_id = SecureRandom.uuid
    @client.update_user({ id: user_id, name: 'Test User' })

    response = @client.update_user_partial({
                                             id: user_id,
                                             set: {
                                               teams: ['blue'],
                                               teams_role: { 'blue' => 'admin' }
                                             }
                                           })

    expect(response['users'][user_id]['teams']).to eq(['blue'])
    expect(response['users'][user_id]['teams_role']['blue']).to eq('admin')
  end

  it 'deletes a user' do
    response = @client.delete_user(@random_user[:id])
    expect(response).to include 'user'
    expect(response['user']['id']).to eq(@random_user[:id])
  end

  it 'deletes a user with mark delete' do
    response = @client.delete_user(@random_user[:id], mark_messages_deleted: true, hard_delete: true)
    expect(response).to include 'user'
    expect(response['user']['id']).to eq(@random_user[:id])
  end

  it 'deactivates a user' do
    response = @client.deactivate_user(@random_user[:id])
    expect(response).to include 'user'
    expect(response['user']['id']).to eq(@random_user[:id])
  end

  it 'deactivates multiple users' do
    response = @client.deactivate_users([@random_users[0][:id], @random_users[1][:id]])
    expect(response).to include 'task_id'
    expect(response['task_id']).not_to be_empty
  end

  it 'raises an error if user_ids is not an array' do
    expect { @client.deactivate_users('not an array') }.to raise_error(TypeError)
  end

  it 'raises an error if user_ids is empty' do
    expect { @client.deactivate_users([]) }.to raise_error(ArgumentError)
  end

  it 'reactivates a user' do
    @client.deactivate_user(@random_user[:id])
    response = @client.reactivate_user(@random_user[:id])
    expect(response).to include 'user'
    expect(response['user']['id']).to eq(@random_user[:id])
  end

  it 'exports a user' do
    response = @client.export_user(@gandalf)
    expect(response).to include 'user'
    expect(response['user']['name']).to eq('Gandalf the Grey')
  end

  it 'shadow bans a user' do
    @client.shadow_ban(@random_user[:id], user_id: @random_users[0][:id])

    msg_id = SecureRandom.uuid
    response = @channel.send_message({
                                       id: msg_id,
                                       text: 'Hello world'
                                     }, @random_user[:id])
    expect(response['message']['shadowed']).to eq(false)
    response = @client.get_message(msg_id)
    expect(response['message']['shadowed']).to eq(true)

    @client.remove_shadow_ban(@random_user[:id], user_id: @random_users[0][:id])

    msg_id = SecureRandom.uuid
    response = @channel.send_message({
                                       id: msg_id,
                                       text: 'Hello world'
                                     }, @random_user[:id])
    expect(response['message']['shadowed']).to eq(false)
    response = @client.get_message(msg_id)
    expect(response['message']['shadowed']).to eq(false)
  end

  it 'bans a user' do
    @client.ban_user(@random_user[:id], user_id: @random_users[0][:id])
  end

  it 'unbans a user' do
    @client.ban_user(@random_user[:id], user_id: @random_users[0][:id])
    @client.unban_user(@random_user[:id], user_id: @random_users[0][:id])
  end

  it 'flags\unflags a user' do
    @client.flag_user(@random_user[:id], user_id: @random_users[0][:id])
    @client.unflag_user(@random_user[:id], user_id: @random_users[0][:id])
  end

  it 'flags\unflags message' do
    msg_id = SecureRandom.uuid
    @channel.send_message({
                            'id' => msg_id,
                            'text' => 'Hello world'
                          }, @random_user[:id])

    @client.flag_message(msg_id, user_id: @random_users[0][:id])
    @client.unflag_message(msg_id, user_id: @random_users[0][:id])
  end

  it 'queries message flags' do
    msg_id = SecureRandom.uuid
    @channel.send_message({
                            'id' => msg_id,
                            'text' => 'Hello world'
                          }, @random_user[:id])

    @client.flag_message(msg_id, user_id: @random_users[0][:id])
    response = @client.query_message_flags({ 'user_id' => { '$in' => [@random_user[:id]] } })
    expect(response['flags'].length).to eq 1
  end

  it 'queries flag reports' do
    msg_id = SecureRandom.uuid
    @channel.send_message({
                            'id' => msg_id,
                            'text' => 'Hello world'
                          }, @random_user[:id])
    @client.flag_message(msg_id, user_id: @random_users[0][:id])
    response = @client.query_flag_reports(message_id: msg_id)
    expect(response['flag_reports'].length).to eq 1

    response = @client.review_flag_report(
      response['flag_reports'][0]['id'],
      'reviewed',
      @random_user[:id],
      custom: 'reason_a'
    )
    expect(response['flag_report']).not_to be_nil
  end

  it 'marks everything as read' do
    @client.mark_all_read(@random_user[:id])
  end

  describe '#get_message' do
    # runs before all tests in this describe block once
    before(:all) do
      @user_id = SecureRandom.uuid
      @msg_id = SecureRandom.uuid
      @channel.send_message({
                              'id' => @msg_id,
                              'text' => 'This is not deleted'
                            }, @user_id)
      @deleted_msg_id = SecureRandom.uuid
      @channel.send_message({
                              'id' => @deleted_msg_id,
                              'text' => 'This is deleted'
                            }, @user_id)
      @client.delete_message(@deleted_msg_id)
    end

    it 'gets message by id' do
      response = @client.get_message(@msg_id)
      message = response['message']
      expect(message['id']).to eq(@msg_id)
    end

    it 'gets deleted message when show_deleted_message is true' do
      response = @client.get_message(@deleted_msg_id, show_deleted_message: true)
      message = response['message']
      expect(message['id']).to eq(@deleted_msg_id)
    end

    it 'also it gets non-deleted message when show_deleted_message is true' do
      response = @client.get_message(@msg_id, show_deleted_message: true)
      message = response['message']
      expect(message['id']).to eq(@msg_id)
    end
  end

  it 'pins and unpins a message' do
    msg_id = SecureRandom.uuid
    response = @channel.send_message({
                                       'id' => msg_id,
                                       'text' => 'Hello world'
                                     }, @random_user[:id])
    response = @client.pin_message(response['message']['id'], @random_user[:id])
    expect(response['message']['pinned_by']['id']).to eq(@random_user[:id])

    response = @client.unpin_message(response['message']['id'], @random_user[:id])
    expect(response['message']['pinned_by']).to eq(nil)
  end

  it 'updates a message' do
    msg_id = SecureRandom.uuid
    response = @channel.send_message({
                                       'id' => msg_id,
                                       'text' => 'Hello world'
                                     }, @random_user[:id])
    expect(response['message']['text']).to eq('Hello world')
    @client.update_message({
                             'id' => msg_id,
                             'awesome' => true,
                             'text' => 'helloworld',
                             'user' => { 'id' => response['message']['user']['id'] }
                           })
  end

  it 'updates a message partially' do
    msg_id = SecureRandom.uuid
    response = @channel.send_message(
      {
        id: msg_id,
        text: 'Hello world'
      }, @random_user[:id]
    )
    expect(response['message']['text']).to eq('Hello world')
    response = @client.update_message_partial(msg_id,
                                              {
                                                set: {
                                                  awesome: true,
                                                  text: 'helloworld'
                                                }
                                              }, user_id: @random_user[:id])
    expect(response['message']['text']).to eq('helloworld')
    expect(response['message']['awesome']).to eq(true)
  end

  it 'deletes a message' do
    msg_id = SecureRandom.uuid
    @channel.send_message({
                            'id' => msg_id,
                            'text' => 'hello world'
                          }, @random_user[:id])
    @client.delete_message(msg_id)
  end

  it 'hard deletes a message' do
    msg_id = SecureRandom.uuid
    @channel.send_message({
                            'id' => msg_id,
                            'text' => 'hello world'
                          }, @random_user[:id])
    @client.delete_message(msg_id, hard: true)
  end

  it 'undeletes a message' do
    msg_id = SecureRandom.uuid
    user_id = @random_user[:id]
    @channel.send_message({
                            'id' => msg_id,
                            'text' => 'to be deleted and restored'
                          }, user_id)
    # soft delete
    @client.delete_message(msg_id)

    # check it is deleted
    response = @client.get_message(msg_id, show_deleted_message: true)
    expect(response['message']['deleted_at']).not_to be_nil

    # now undelete
    @client.undelete_message(msg_id, user_id)

    # now we should be able to get it without an error and without the flag
    response = @client.get_message(msg_id)
    expect(response['message']['deleted_at']).to be_nil
  end

  it 'query banned users' do
    @client.ban_user(@random_user[:id], user_id: @random_users[0][:id], reason: 'rubytest')
    response = @client.query_banned_users({ 'reason' => 'rubytest' }, limit: 1)
    expect(response['bans'].length).to eq 1
  end

  it 'queries users' do
    response = @client.query_users({ 'race' => { '$eq' => 'Hobbit' } }, sort: { 'age' => -1 })
    expect(response['users'].length).to eq 2
    expect([50, 38]).to eq(response['users'].map { |u| u['age'] })
  end

  it 'queries channels' do
    response = @client.query_channels({ 'members' => { '$in' => [@legolas] } }, sort: { 'id' => 1 })
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['id']).to eq @channel.id
    expect(response['channels'][0]['members'].length).to eq 4
  end

  xit 'run message action' do
    resp = @channel.send_message({ text: '/giphy wave' }, @random_user[:id])
    @client.run_message_action(resp['message']['id'], { user: { id: @random_user[:id] }, form_data: { image_action: 'shuffle' } })
  end

  it 'handles devices' do
    response = @client.get_devices(@random_user[:id])
    expect(response).to include 'devices'
    expect(response['devices'].length).to eq 0

    @client.add_device(SecureRandom.uuid, 'apn', @random_user[:id])
    response = @client.get_devices(@random_user[:id])
    expect(response['devices'].length).to eq 1

    @client.delete_device(response['devices'][0]['id'], @random_user[:id])
    @client.add_device(SecureRandom.uuid, 'apn', @random_user[:id])
    response = @client.get_devices(@random_user[:id])
    expect(response['devices'].length).to eq 1
  end

  describe 'get rate limits' do
    it 'lists all limits' do
      response = @client.get_rate_limits
      expect(response['android']).not_to be_nil
      expect(response['ios']).not_to be_nil
      expect(response['web']).not_to be_nil
      expect(response['server_side']).not_to be_nil
    end

    it 'lists limits for a single platform' do
      response = @client.get_rate_limits(server_side: true)
      expect(response['server_side']).not_to be_nil
      expect(response['android']).to be_nil
      expect(response['ios']).to be_nil
      expect(response['web']).to be_nil
    end

    it 'lists limits for a few endpoints' do
      response = @client.get_rate_limits(server_side: true, android: true, endpoints: %w[GetRateLimits QueryChannels])
      expect(response['ios']).to be_nil
      expect(response['web']).to be_nil
      expect(response['android']).not_to be_nil
      expect(response['android'].length).to eq(2)
      expect(response['android']['GetRateLimits']['limit']).to eq(response['android']['GetRateLimits']['remaining'])
      expect(response['server_side']).not_to be_nil
      expect(response['server_side'].length).to eq(2)
      expect(response['server_side']['GetRateLimits']['limit']).to be > response['server_side']['GetRateLimits']['remaining']
    end
  end

  describe 'search' do
    it 'search for messages' do
      text = SecureRandom.uuid
      @channel.send_message({ text: text }, @fellowship_of_the_ring[2][:id])
      resp = @client.search({ members: { '$in' => [@fellowship_of_the_ring[2][:id]] } }, text)
      p resp
      expect(resp['results'].length).to eq(1)
    end

    it 'search for messages with filter conditions' do
      text = SecureRandom.uuid
      @channel.send_message({ text: text }, @legolas)
      resp = @client.search({ members: { '$in' => [@legolas] } }, { text: { '$q': text } })
      expect(resp['results'].length).to eq(1)
    end

    it 'offset with sort should fail' do
      expect do
        @client.search({ members: { '$in' => [@legolas] } }, SecureRandom.uuid, sort: { created_at: -1 }, offset: 2)
      end.to raise_error(/cannot use offset with next or sort parameters/)
    end

    it 'offset with next should fail' do
      expect do
        @client.search({ members: { '$in' => [@legolas] } }, SecureRandom.uuid, offset: 2, next: SecureRandom.uuid)
      end.to raise_error(/cannot use offset with next or sort parameters/)
    end

    xit 'search for messages with sorting' do
      text = SecureRandom.uuid
      message_ids = ["0-#{text}", "1-#{text}"]
      @channel.send_message({ id: message_ids[0], text: text }, @legolas)
      @channel.send_message({ id: message_ids[1], text: text }, @legolas)
      page1 = @client.search({ members: { '$in' => [@legolas] } }, text, sort: [{ created_at: -1 }], limit: 1)
      expect(page1['results'].length).to eq
      expect(page1['results'][0]['message']['id']).to eq(message_ids[1])
      expect(page1['next']).not_to be_empty
      page2 = @client.search({ members: { '$in' => [@legolas] } }, text, limit: 1, next: page1['next'])
      expect(page2['results'].length).to eq(1)
      expect(page2['results'][0]['message']['id']).to eq(message_ids[0])
      expect(page2['previous']).not_to be_empty
    end
  end

  describe 'unread count' do
    before(:all) do
      @user_id = SecureRandom.uuid
      @client.update_users([{ id: @user_id }])
      @channel = @client.channel('team', channel_id: SecureRandom.uuid)
      @channel.create(@user_id)
      @channel.add_members([@user_id])
    end

    before(:each) do
      @client.mark_all_read(@user_id)
    end

    it 'gets unread count' do
      resp = @client.unread_counts(@user_id)
      expect(resp['total_unread_count']).to eq 0
    end

    it 'gets unread count if there are unread messages' do
      @channel.send_message({ text: 'Hello world' }, @random_user[:id])
      resp = @client.unread_counts(@user_id)
      expect(resp['total_unread_count']).to eq 1
    end

    it 'gets unread count for a channel' do
      @message = @channel.send_message({ text: 'Hello world' }, @random_user[:id])
      resp = @client.unread_counts(@user_id)
      expect(resp['total_unread_count']).to eq 1
      expect(resp['channels'].length).to eq 1
      expect(resp['channels'][0]['channel_id']).to eq @channel.cid
      expect(resp['channels'][0]['unread_count']).to eq 1
      expect(resp['channels'][0]['last_read']).not_to be_nil
    end
  end

  describe 'unread counts batch' do
    before(:all) do
      @user_id1 = SecureRandom.uuid
      @user_id2 = SecureRandom.uuid
      @client.update_users([{ id: @user_id1 }, { id: @user_id2 }])
      @channel = @client.channel('team', channel_id: SecureRandom.uuid)
      @channel.create(@user_id1)
      @channel.add_members([@user_id1, @user_id2])
    end

    before(:each) do
      @client.mark_all_read(@user_id1)
      @client.mark_all_read(@user_id2)
    end

    it 'gets unread counts for a batch of users' do
      resp = @client.unread_counts_batch([@user_id1, @user_id2])
      expect(resp['counts_by_user'].length).to eq 0
    end

    it 'gets unread counts for a batch of users with unread messages' do
      @channel.send_message({ text: 'Hello world' }, @user_id1)
      @channel.send_message({ text: 'Hello world' }, @user_id2)

      resp = @client.unread_counts_batch([@user_id1, @user_id2])
      expect(resp['counts_by_user'].length).to eq 2
      expect(resp['counts_by_user'][@user_id1]['total_unread_count']).to eq 1
      expect(resp['counts_by_user'][@user_id2]['total_unread_count']).to eq 1
      expect(resp['counts_by_user'][@user_id1]['channels'].length).to eq 1
      expect(resp['counts_by_user'][@user_id2]['channels'].length).to eq 1
      expect(resp['counts_by_user'][@user_id1]['channels'][0]['channel_id']).to eq @channel.cid
    end
  end

  describe 'blocklist' do
    before(:all) do
      @blocklist = SecureRandom.uuid
    end

    it 'list available blocklists' do
      resp = @client.list_blocklists
      expect(resp['blocklists'].map { |b| b['name'] }).to include StreamChat::DEFAULT_BLOCKLIST
    end

    it 'get default blocklist' do
      resp = @client.get_blocklist(StreamChat::DEFAULT_BLOCKLIST)
      expect(resp['blocklist']['name']).to eq StreamChat::DEFAULT_BLOCKLIST
    end

    it 'create a new blocklist' do
      @client.create_blocklist(@blocklist, %w[fudge cream sugar])
    end

    it 'list available blocklists' do
      resp = @client.list_blocklists
      expect(resp['blocklists'].length).to be >= 2
    end

    it 'get blocklist info' do
      resp = @client.get_blocklist(@blocklist)
      expect(resp['blocklist']['name']).to eq @blocklist
      expect(resp['blocklist']['words']).to eq %w[fudge cream sugar]
    end

    it 'update a default blocklist should fail' do
      expect do
        @client.update_blocklist(StreamChat::DEFAULT_BLOCKLIST, %w[fudge cream sugar vanilla])
      end.to raise_error(/cannot update the builtin block list/)
    end

    it 'update blocklist' do
      @client.update_blocklist(@blocklist, %w[fudge cream sugar vanilla])
    end

    it 'get blocklist info again' do
      resp = @client.get_blocklist(@blocklist)
      expect(resp['blocklist']['name']).to eq @blocklist
      expect(resp['blocklist']['words']).to eq %w[fudge cream sugar vanilla]
    end

    it 'use the blocklist for a channel type' do
      @client.update_channel_type('team', blocklist: @blocklist, blocklist_behavior: 'block')
    end

    xit 'should block messages that match the blocklist' do
      resp = @channel.send_message({ text: 'put some sugar and fudge on that!' }, @random_user[:id])
      expect(resp['message']['text']).to eq 'Automod blocked your message'
      expect(resp['message']['type']).to eq 'error'
    end

    it 'update blocklist again' do
      @client.update_blocklist(@blocklist, %w[fudge cream sugar vanilla jam])
    end

    xit 'should block messages that match the blocklist again' do
      resp = @channel.send_message({ text: 'you should add more jam there ;)' }, @random_user[:id])
      expect(resp['message']['text']).to eq 'Automod blocked your message'
      expect(resp['message']['type']).to eq 'error'
    end

    it 'delete a blocklist' do
      @client.delete_blocklist(@blocklist)
    end

    it 'should not block messages anymore' do
      resp = @channel.send_message({ text: 'put some sugar and fudge on that!' }, @random_user[:id])
      expect(resp['message']['text']).to eq 'put some sugar and fudge on that!'
    end

    it 'list available blocklists' do
      resp = @client.list_blocklists
      expect(resp['blocklists'].length).to be >= 1
      expect(resp['blocklists'].map { |b| b['name'] }).not_to include @blocklist
    end

    it 'delete a default blocklist should fail' do
      expect do
        @client.delete_blocklist(StreamChat::DEFAULT_BLOCKLIST)
      end.to raise_error(
        /cannot delete the builtin block list/
      )
    end
  end

  it 'check status for a task that does not exist' do
    expect do
      @client.get_export_channel_status(SecureRandom.uuid)
    end.to raise_error(
      /Can't find task with id/
    )
  end

  it 'check status for a task that does not exist' do
    expect do
      @client.get_task(SecureRandom.uuid)
    end.to raise_error(
      /Can't find task with id/
    )
  end

  it 'request the export for a channel that does not exist' do
    expect do
      @client.export_channels({ type: 'messaging', id: SecureRandom.uuid })
    end.to raise_error StreamChat::StreamAPIException
  end

  it 'request the channel export' do
    ch = @client.channel('messaging', channel_id: SecureRandom.uuid)
    ch.create(@random_user[:id])
    ch.send_message({ text: 'Hey Joni' }, @random_user[:id])

    options = { clear_deleted_message_text: true, include_truncated_messages: true }
    resp = @client.export_channels({ type: ch.channel_type, id: ch.id }, **options)
    expect(resp['task_id']).not_to be_empty

    task_id = resp['task_id']
    loop do
      resp = @client.get_export_channel_status(task_id)
      expect(resp['status']).not_to be_empty
      expect(resp['created_at']).not_to be_empty
      expect(resp['updated_at']).not_to be_empty
      if resp['status'] == 'completed'
        expect(resp['result']).not_to be_empty
        expect(resp['result']['url']).not_to be_empty
        expect(resp).not_to include 'error'
        break
      end
      sleep(0.5)
    end
  end

  it 'request users export' do
    user_id1 = SecureRandom.uuid
    @client.update_users([{ id: user_id1 }])

    resp = @client.export_users([user_id1])
    expect(resp['task_id']).not_to be_empty

    task_id = resp['task_id']
    loop do
      resp = @client.get_task(task_id)
      expect(resp['status']).not_to be_empty
      expect(resp['created_at']).not_to be_empty
      expect(resp['updated_at']).not_to be_empty
      if resp['status'] == 'completed'
        expect(resp['result']).not_to be_empty
        expect(resp['result']['url']).not_to be_empty
        expect(resp).not_to include 'error'
        break
      end
      sleep(0.5)
    end
  end

  it 'request delete channels' do
    ch1 = @client.channel('messaging', channel_id: SecureRandom.uuid)
    ch1.create(@random_user[:id])
    ch1.send_message({ text: 'Hey Joni' }, @random_user[:id])
    cid1 = "#{ch1.channel_type}:#{ch1.id}"

    ch2 = @client.channel('messaging', channel_id: SecureRandom.uuid)
    ch2.create(@random_user[:id])
    ch2.send_message({ text: 'Hey Joni' }, @random_user[:id])
    cid2 = "#{ch2.channel_type}:#{ch2.id}"

    resp = @client.delete_channels([cid1, cid2], hard_delete: true)
    expect(resp['task_id']).not_to be_empty

    task_id = resp['task_id']
    loop do
      resp = @client.get_task(task_id)
      expect(resp['status']).not_to be_empty
      expect(resp['created_at']).not_to be_empty
      expect(resp['updated_at']).not_to be_empty
      if resp['status'] == 'completed'
        result = resp['result']
        expect(result).not_to be_empty
        expect(result[cid1]).not_to be_empty
        expect(result[cid1]['status']).to eq 'ok'
        expect(result[cid2]).not_to be_empty
        expect(result[cid2]['status']).to eq 'ok'
        break
      end
      sleep(0.5)
    end
  end

  it 'request delete users' do
    user_id1 = SecureRandom.uuid
    user_id2 = SecureRandom.uuid
    @client.update_users([{ id: user_id1 }, { id: user_id2 }])

    ch1 = @client.channel('messaging', channel_id: SecureRandom.uuid)
    ch1.create(user_id1)
    ch1.send_message({ text: 'Hey Joni' }, user_id1)

    ch2 = @client.channel('messaging', channel_id: SecureRandom.uuid)
    ch2.create(user_id2)
    ch2.send_message({ text: 'Hey Joni' }, user_id1)

    resp = @client.delete_users([user_id1, user_id2], user: StreamChat::HARD_DELETE)
    expect(resp['task_id']).not_to be_empty

    task_id = resp['task_id']
    resp = @client.get_task(task_id)
    expect(resp['status']).not_to be_empty
  end

  it 'check push notification test are working' do
    message_id = SecureRandom.uuid
    @channel.send_message({ id: message_id, text: SecureRandom.uuid }, @legolas)
    resp = @client.check_push({ message_id: message_id, skip_devices: true, user_id: @random_user[:id] })
    expect(resp['rendered_message']).not_to be_empty
  end

  it 'check_sqs with an invalid queue url should fail' do
    resp = @client.check_sqs('key', 'secret', 'https://foo.com/bar')
    expect(resp['status']).to eq 'error'
    expect(resp['error']).to include 'invalid SQS url'
  end

  it 'check_sns with an invalid topic arn should fail' do
    resp = @client.check_sns('key', 'secret', 'arn:aws:sns:us-east-1:123456789012:sns-topic')
    expect(resp['status']).to eq 'error'
    expect(resp['error']).to include 'publishing the message failed.'
  end

  it 'can create a guest if it"s allowed' do
    guest_user = @client.create_guest({ user: { id: SecureRandom.uuid } })
    expect(guest_user['access_token']).not_to be_empty
  rescue StreamChat::StreamAPIException
    # Guest user isn't turned on for every test app, so ignore it
  end

  it 'can send custom events' do
    @client.send_user_event(@random_user[:id], { event: { type: 'friendship-request' } })
  end

  it 'can translate a message' do
    message_id = SecureRandom.uuid
    @channel.send_message({ id: message_id, text: SecureRandom.uuid }, @legolas)
    response = @client.translate_message(message_id, 'hu')
    expect(response['message']).not_to be_empty
  end

  describe 'custom commands' do
    before(:all) do
      @cmd = SecureRandom.uuid
    end

    it 'create a command' do
      cmd = @client.create_command({ name: @cmd, description: 'I am testing' })['command']
      expect(cmd['name']).to eq @cmd
      expect(cmd['description']).to eq 'I am testing'
    end

    it 'get that command' do
      cmd = @client.get_command(@cmd)
      expect(cmd['name']).to eq @cmd
      expect(cmd['description']).to eq 'I am testing'
    end

    it 'update that command' do
      cmd = @client.update_command(@cmd, { description: 'I tested' })['command']
      expect(cmd['name']).to eq @cmd
      expect(cmd['description']).to eq 'I tested'
    end

    it 'delete that command' do
      @client.delete_command(@cmd)
    end

    it 'list commands' do
      cmds = @client.list_commands['commands']
      cmds.each do |cmd|
        expect(cmd['name']).not_to eq @cmd
      end
    end

    it 'import end2end' do
      url_resp = @client.create_import_url("#{SecureRandom.uuid}.json")
      expect(url_resp['upload_url']).not_to be_empty
      expect(url_resp['path']).not_to be_empty

      Faraday.put(url_resp['upload_url'], '{}', 'Content-Type' => 'application/json')

      create_resp = @client.create_import(url_resp['path'], 'upsert')
      expect(create_resp['import_task']['id']).not_to be_empty

      get_resp = @client.get_import(create_resp['import_task']['id'])
      expect(get_resp['import_task']['id']).to eq create_resp['import_task']['id']

      list_resp = @client.list_imports({ limit: 1 })
      expect(list_resp['import_tasks'].length).to eq 1
    end

    it 'can query drafts' do
      # Create multiple drafts in different channels
      draft1 = { 'text' => 'Draft in channel 1' }
      @channel.create_draft(draft1, @random_user[:id])

      # Create another channel with a draft
      channel2 = @client.channel('messaging', data: { 'members' => @random_users.map { |u| u[:id] } })
      channel2.create(@random_user[:id])

      draft2 = { 'text' => 'Draft in channel 2' }
      channel2.create_draft(draft2, @random_user[:id])

      # Sort by created_at
      sort = [{ 'field' => 'created_at', 'direction' => 1 }]
      response = @client.query_drafts(@random_user[:id], sort: sort)
      expect(response['drafts']).not_to be_empty
      expect(response['drafts'].length).to eq(2)
      expect(response['drafts'][0]['channel']['id']).to eq(@channel.id)
      expect(response['drafts'][1]['channel']['id']).to eq(channel2.id)

      # Query for a specific channel
      response = @client.query_drafts(@random_user[:id], filter: { 'channel_cid' => @channel.cid })
      expect(response['drafts']).not_to be_empty
      expect(response['drafts'].length).to eq(1)
      expect(response['drafts'][0]['channel']['id']).to eq(@channel.id)

      # Query all drafts for the user
      response = @client.query_drafts(@random_user[:id])
      expect(response['drafts']).not_to be_empty
      expect(response['drafts'].length).to eq(2)

      # Paginate
      response = @client.query_drafts(@random_user[:id], sort: sort, limit: 1)
      expect(response['drafts']).not_to be_empty
      expect(response['drafts'].length).to eq(1)
      expect(response['drafts'][0]['channel']['id']).to eq(@channel.id)

      # Cleanup
      begin
        channel2.delete
      rescue StandardError
        # Ignore errors if channel is already deleted
      end
    end
  end

  describe 'permissions' do
    before(:all) do
      @permission_id = SecureRandom.uuid
    end

    it 'create a permission' do
      @client.create_permission({
                                  id: @permission_id,
                                  name: @permission_id,
                                  action: 'CreateChannel',
                                  owner: false,
                                  same_team: false,
                                  condition: {
                                    '$subject.magic_custom_field': 'custom'
                                  }
                                })
    end

    it 'get permission' do
      loop_times 10 do
        permission = @client.get_permission(@permission_id)
        expect(permission['id']).to eq @cmd
        expect(permission['name']).to eq @cmd
      end
    end

    it 'update that permission' do
      loop_times 10 do
        @client.update_permission(@permission_id, {
                                    id: @permission_id,
                                    name: @permission_id,
                                    description: 'desc',
                                    action: 'CreateChannel',
                                    condition: {
                                      '$subject.magic_custom_field': 'custom'
                                    }
                                  })
        permission = @client.get_permission(@permission_id)['permission']
        expect(permission['name']).to eq @permission_id
        expect(permission['description']).to eq 'desc'
      end
    end

    it 'list permissions' do
      loop_times 10 do
        permissions = @client.list_permissions['permissions']
        found = false
        permissions.each do |permission|
          if permission['id'] == @permission_id
            found = true
            break
          end
        end

        expect(found).to be true
      end
    end

    it 'delete that permission' do
      loop_times 10 do
        @client.delete_permission(@permission_id)
      end
    end

    it 'create role' do
      @client.create_role(@permission_id)
    end

    it 'list new role' do
      loop_times 10 do
        roles = @client.list_roles['roles']
        found = false
        roles.each do |role|
          if role['name'] == @permission_id
            found = true
            break
          end
        end
        expect(found).to be true
      end
    end

    it 'delete role' do
      loop_times 10 do
        @client.delete_role @permission_id
      end
    end
  end

  describe '#query_threads' do
    before(:all) do
      # Create a dedicated random user for this block
      @thread_test_user = { id: SecureRandom.uuid }
      @client.upsert_users([@thread_test_user])

      # Create a channel and send a message to create a thread
      @thread_channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true })
      @thread_channel.create(@thread_test_user[:id])

      # Send a message to create a thread
      @thread_message = @thread_channel.send_message({ text: 'Thread parent message' }, @thread_test_user[:id])

      # Send a reply to create a thread
      @thread_channel.send_message({ text: 'Thread reply', parent_id: @thread_message['message']['id'] }, @thread_test_user[:id])
    end

    after(:all) do
      @thread_channel.delete
      @client.delete_user(@thread_test_user[:id])
    end

    it 'queries threads with filter' do
      filter = {
        'created_by_user_id' => { '$eq' => @thread_test_user[:id] }
      }

      response = @client.query_threads(filter, user_id: @thread_test_user[:id])

      expect(response).to include 'threads'
      expect(response['threads'].length).to be >= 1
    end

    it 'queries threads with sort' do
      sort = {
        'created_at' => -1
      }

      response = @client.query_threads({}, sort: sort, user_id: @thread_test_user[:id])

      expect(response).to include 'threads'
      expect(response['threads'].length).to be >= 1
    end

    it 'queries threads with both filter and sort' do
      filter = {
        'created_by_user_id' => { '$eq' => @thread_test_user[:id] }
      }

      sort = {
        'created_at' => -1
      }

      response = @client.query_threads(filter, sort: sort, user_id: @thread_test_user[:id])

      expect(response).to include 'threads'
      expect(response['threads'].length).to be >= 1
    end
  end

  describe 'reminders' do
    before(:all) do
      @channel.update_partial({ config_overrides: { user_message_reminders: true } })
    end

    before(:each) do
      @user_id = @random_user[:id]
      @message = @channel.send_message({ 'text' => 'Hello world' }, @user_id)
      @message_id = @message['message']['id']
    end

    describe 'create_reminder' do
      it 'create reminder' do
        remind_at = DateTime.now + 1
        response = @client.create_reminder(@message_id, @user_id, remind_at)

        expect(response).to include('reminder')
        expect(response['reminder']).to include('message_id', 'user_id', 'remind_at')
        expect(response['reminder']['message_id']).to eq(@message_id)
        expect(response['reminder']['user_id']).to eq(@user_id)
      end

      it 'create reminder without remind_at' do
        response = @client.create_reminder(@message_id, @user_id)

        expect(response).to include('reminder')
        expect(response['reminder']).to include('message_id', 'user_id')
        expect(response['reminder']['message_id']).to eq(@message_id)
        expect(response['reminder']['user_id']).to eq(@user_id)
        expect(response['reminder']['remind_at']).to be_nil
      end
    end

    describe 'update_reminder' do
      before do
        @client.create_reminder(@message_id, @user_id)
      end

      it 'update reminder' do
        new_remind_at = DateTime.now + 2
        response = @client.update_reminder(@message_id, @user_id, new_remind_at)

        expect(response).to include('reminder')
        expect(response['reminder']).to include('message_id', 'user_id', 'remind_at')
        expect(response['reminder']['message_id']).to eq(@message_id)
        expect(response['reminder']['user_id']).to eq(@user_id)
        expect(DateTime.parse(response['reminder']['remind_at'])).to be_within(1).of(new_remind_at)
      end
    end

    describe 'delete_reminder' do
      before do
        @client.create_reminder(@message_id, @user_id)
      end

      it 'delete reminder' do
        response = @client.delete_reminder(@message_id, @user_id)
        expect(response).to be_a(Hash)
      end
    end

    describe 'query_reminders' do
      before do
        @reminder = @client.create_reminder(@message_id, @user_id)
      end

      it 'query reminders' do
        # Query reminders for the user
        response = @client.query_reminders(@user_id)

        expect(response).to include('reminders')
        expect(response['reminders']).to be_an(Array)
        expect(response['reminders'].length).to be >= 1
      end

      it 'query reminders with channel filter' do
        # Query reminders for the user in a specific channel
        filter = { 'channel_cid' => @channel.cid }
        response = @client.query_reminders(@user_id, filter)

        expect(response).to include('reminders')
        expect(response['reminders']).to be_an(Array)
        expect(response['reminders'].length).to be >= 1

        # All reminders should have a channel_cid
        response['reminders'].each do |reminder|
          expect(reminder).to include('channel_cid')
        end
      end
    end
  end
end
