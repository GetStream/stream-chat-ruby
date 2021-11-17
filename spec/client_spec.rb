# frozen_string_literal: true

require 'jwt'
require 'securerandom'
require 'stream-chat'

describe StreamChat::Client do
  before(:all) do
    @client = StreamChat::Client.new(ENV['STREAM_CHAT_API_KEY'], ENV['STREAM_CHAT_API_SECRET'], base_url: ENV['STREAM_CHAT_API_HOST'])

    @fellowship_of_the_ring = [
      { id: 'frodo-baggins', name: 'Frodo Baggins', race: 'Hobbit', age: 50 },
      { id: 'sam-gamgee', name: 'Samwise Gamgee', race: 'Hobbit', age: 38 },
      { id: 'gandalf', name: 'Gandalf the Grey', race: 'Istari' },
      { id: 'legolas', name: 'Legolas', race: 'Elf', age: 500 }
    ]
    @client.update_users(@fellowship_of_the_ring)
    @channel = @client.channel('team', channel_id: 'fellowship-of-the-ring',
                                       data: { members: @fellowship_of_the_ring.map { |fellow| fellow[:id] } })
    @channel.create('gandalf')
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid }, { id: SecureRandom.uuid }]
    @random_user = { id: SecureRandom.uuid }
    response = @client.update_user(@random_user)
    expect(response).to include 'users'
    expect(response['users']).to include @random_user[:id]
    @client.update_users(@random_users)
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

  it 'updates a user' do
    user = { id: SecureRandom.uuid }
    response = @client.update_user(user)
    expect(response).to include 'users'
    expect(response['users']).to include user[:id]
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

  it 'reactivates a user' do
    @client.deactivate_user(@random_user[:id])
    response = @client.reactivate_user(@random_user[:id])
    expect(response).to include 'user'
    expect(response['user']['id']).to eq(@random_user[:id])
  end

  it 'exports a user' do
    response = @client.export_user('gandalf')
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

  it 'marks everything as read' do
    @client.mark_all_read(@random_user[:id])
  end

  it 'gets message by id' do
    msg_id = SecureRandom.uuid
    message = @channel.send_message({
                                      'id' => msg_id,
                                      'text' => 'Hello world'
                                    }, @random_user[:id])[:message]

    expect(@client.get_message(msg_id)[:message]).to eq(message)
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

  it 'queries users' do
    response = @client.query_users({ 'race' => { '$eq' => 'Hobbit' } }, sort: { 'age' => -1 })
    expect(response['users'].length).to eq 2
    expect([50, 38]).to eq(response['users'].map { |u| u['age'] })
  end

  it 'queries channels' do
    response = @client.query_channels({ 'members' => { '$in' => ['legolas'] } }, sort: { 'id' => 1 })
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['id']).to eq 'fellowship-of-the-ring'
    expect(response['channels'][0]['members'].length).to eq 4
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
      @channel.send_message({ text: text }, 'legolas')
      resp = @client.search({ members: { '$in' => ['legolas'] } }, text)
      expect(resp['results'].length).to eq(1)
    end
    it 'search for messages with filter conditions' do
      text = SecureRandom.uuid
      @channel.send_message({ text: text }, 'legolas')
      resp = @client.search({ members: { '$in' => ['legolas'] } }, { text: { '$q': text } })
      expect(resp['results'].length).to eq(1)
    end
    it 'offset with sort should fail' do
      expect do
        @client.search({ members: { '$in' => ['legolas'] } }, SecureRandom.uuid, sort: [{ created_at: -1 }], offset: 2)
      end.to raise_error(/cannot use offset with next or sort parameters/)
    end
    it 'offset with next should fail' do
      expect do
        @client.search({ members: { '$in' => ['legolas'] } }, SecureRandom.uuid,  offset: 2, next: SecureRandom.uuid)
      end.to raise_error(/cannot use offset with next or sort parameters/)
    end
    xit 'search for messages with sorting' do
      text = SecureRandom.uuid
      message_ids = ["0-#{text}", "1-#{text}"]
      @channel.send_message({ id: message_ids[0], text: text }, 'legolas')
      @channel.send_message({ id: message_ids[1], text: text }, 'legolas')
      page1 = @client.search({ members: { '$in' => ['legolas'] } }, text, sort: [{ created_at: -1 }], limit: 1)
      expect(page1['results'].length).to eq
      expect(page1['results'][0]['message']['id']).to eq(message_ids[1])
      expect(page1['next']).not_to be_empty
      page2 = @client.search({ members: { '$in' => ['legolas'] } }, text, limit: 1, next: page1['next'])
      expect(page2['results'].length).to eq(1)
      expect(page2['results'][0]['message']['id']).to eq(message_ids[0])
      expect(page2['previous']).not_to be_empty
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
    end.to raise_error
  end

  it 'request the channel export' do
    ch = @client.channel('messaging', channel_id: SecureRandom.uuid)
    ch.create(@random_user[:id])
    ch.send_message({ text: 'Hey Joni' }, @random_user[:id])

    resp = @client.export_channels({ type: ch.channel_type, id: ch.id })
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
    loop do
      resp = @client.get_task(task_id)
      expect(resp['status']).not_to be_empty
      expect(resp['created_at']).not_to be_empty
      expect(resp['updated_at']).not_to be_empty
      if resp['status'] == 'completed'
        result = resp['result']
        expect(result).not_to be_empty
        expect(result[user_id1]).not_to be_empty
        expect(result[user_id1]['status']).to eq 'ok'
        expect(result[user_id2]).not_to be_empty
        expect(result[user_id2]['status']).to eq 'ok'
        break
      end
      sleep(0.5)
    end
  end

  it 'check_sqs with an invalid queue url should fail' do
    resp = @client.check_sqs('key', 'secret', 'https://foo.com/bar')
    expect(resp['status']).to eq 'error'
    expect(resp['error']).to include 'invalid SQS url'
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

    it 'get that permission' do
      permission = @client.get_permission(@permission_id)
      expect(permission['id']).to eq @cmd
      expect(permission['name']).to eq @cmd
    end

    it 'update that permission' do
      @client.update_permission(@permission_id, { 
        id: @permission_id, 
        name: @permission_id, 
        description: 'desc', 
        action: 'CreateChannel',
        condition: {
          '$subject.magic_custom_field': 'custom'
        }
        })
      permission = @client.get_permission(@permission_id)
      expect(permission['name']).to eq @permission_id
      expect(permission['description']).to eq 'desc'
    end

    it 'list permissions' do
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

    it 'delete that permission' do
      @client.delete_permission(@permission_id)
    end
  end
end
