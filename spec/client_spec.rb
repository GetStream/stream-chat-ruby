require 'jwt'
require 'securerandom'
require 'stream-chat'

describe StreamChat::Client do
  before(:all) do
    @client = StreamChat::Client.new(ENV['STREAM_CHAT_API_KEY'], ENV['STREAM_CHAT_API_SECRET'], {base_url: ENV['STREAM_CHAT_API_HOST']})

    @fellowship_of_the_ring = [
      {id: 'frodo-baggins', name: 'Frodo Baggins', race: 'Hobbit', age: 50},
      {id: 'sam-gamgee', name: 'Samwise Gamgee', race: 'Hobbit', age: 38},
      {id: 'gandalf', name: 'Gandalf the Grey', race: 'Istari'},
      {id: 'legolas', name: 'Legolas', race: 'Elf', age: 500}
    ]
    @client.update_users(@fellowship_of_the_ring)
    @channel = @client.channel('team', channel_id: 'fellowship-of-the-ring',
                              data: { members: @fellowship_of_the_ring.map { |fellow| fellow[:id] }})
    @channel.create('gandalf')
  end

  before(:each) do
    @random_users = [{id: SecureRandom.uuid}, {id: SecureRandom.uuid}]
    @random_user = {id: SecureRandom.uuid}
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
    user = {id: SecureRandom.uuid}
    response = @client.update_user(user)
    expect(response).to include 'users'
    expect(response['users']).to include user[:id]
  end

  it 'updates multiple users' do
    users = [{id: SecureRandom.uuid}, {id: SecureRandom.uuid}]
    response = @client.update_users(users)
    expect(response).to include 'users'
    expect(response['users']).to include users[0][:id]
  end

  it 'deletes a user' do
    response = @client.delete_user(@random_user[:id])
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
    response = @channel.send_message({
      'id' => msg_id,
      'text' => 'Hello world'
    }, @random_user[:id])

    @client.flag_message(msg_id, user_id: @random_users[0][:id])
    @client.unflag_message(msg_id, user_id: @random_users[0][:id])
  end

  it 'marks everything as read' do
    @client.mark_all_read(@random_user[:id])
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
      'user' => {'id' => response['message']['user']['id']}
    })
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
    response = @client.query_users({'race' => {'$eq' => 'Hobbit'}}, sort: {'age' => -1})
    expect(response['users'].length).to eq 2
    expect([50, 38]).to eq response['users'].map { |u| u['age'] }
  end

  it 'queries channels' do
    response = @client.query_channels({'members' => {'$in' => ['legolas']}}, sort: {'id' => 1})
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['id']).to eq 'fellowship-of-the-ring'
    expect(response['channels'][0]['members'].length).to eq 4
  end

  it 'handles devices' do
    response = @client.get_devices(@random_user[:id])
    expect(response).to include 'devices'
    expect(response['devices'].length).to eq 0

    @client.add_device(SecureRandom.uuid, "apn", @random_user[:id])
    response = @client.get_devices(@random_user[:id])
    expect(response['devices'].length).to eq 1

    @client.delete_device(response['devices'][0]['id'], @random_user[:id])
    @client.add_device(SecureRandom.uuid, "apn", @random_user[:id])
    response = @client.get_devices(@random_user[:id])
    expect(response['devices'].length).to eq 1
  end
end

