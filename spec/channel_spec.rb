# frozen_string_literal: true

require 'securerandom'
require 'stream-chat'

describe StreamChat::Channel do
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
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid, name: 'b' }, { id: SecureRandom.uuid, name: 'a' }]
    @client.upsert_users(@random_users)

    @random_user = { id: SecureRandom.uuid }
    response = @client.upsert_user(@random_user)
    expect(response).to include 'users'
    expect(response['users']).to include @random_user[:id]

    @channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { 'test' => true, 'language' => 'ruby' })
    @channel.create(@random_user[:id])
  end

  it 'can create channel without id' do
    channel = @client.channel('messaging', data: { 'members' => @random_users.map { |u| u[:id] } })
    expect(channel.id).to eq nil

    channel.create(@random_users[0][:id])
    expect(channel.id).not_to eq nil
  end

  it 'can send events' do
    response = @channel.send_event({ 'type' => 'typing.start' }, @random_user[:id])
    expect(response).to include 'event'
    expect(response['event']['type']).to eq 'typing.start'
  end

  it 'can get many messages' do
    msg = @channel.send_message({ text: 'hi' }, @random_user[:id])
    response = @channel.get_messages([msg['message']['id']])
    expect(response['messages']).not_to be_empty
  end

  it 'can send reactions' do
    msg = @channel.send_message({ 'text' => 'hi' }, @random_user[:id])
    response = @channel.send_reaction(msg['message']['id'], { 'type' => 'love' }, @random_user[:id])
    expect(response).to include 'message'
    expect(response['message']['latest_reactions'].length).to eq 1
    expect(response['message']['latest_reactions'][0]['type']).to eq 'love'
  end

  it 'can delete a reaction' do
    msg = @channel.send_message({ 'text' => 'hi' }, @random_user[:id])
    @channel.send_reaction(msg['message']['id'], { 'type' => 'love' }, @random_user[:id])
    response = @channel.delete_reaction(msg['message']['id'], 'love', @random_user[:id])
    expect(response).to include 'message'
    expect(response['message']['latest_reactions'].length).to eq 0
  end

  it 'can mute and unmute a channel' do
    response = @channel.mute(@random_user[:id])
    expect(response['channel_mute']['channel']['cid']).not_to be_empty

    @channel.unmute(@random_user[:id])
  end

  it 'can update metadata' do
    response = @channel.update({ 'motd' => 'one apple a day...' })
    expect(response).to include 'channel'
    expect(response['channel']['motd']).to eq 'one apple a day...'
  end

  it 'can update metadata partial' do
    @channel.update_partial({ color: 'blue', age: 30 }, ['motd'])
    response = @channel.query
    expect(response['channel']['color']).to eq 'blue'
    expect(response['channel']['age']).to eq 30
    expect(response['channel']).not_to include 'motd'

    @channel.update_partial({ color: 'red' }, ['age'])
    response = @channel.query
    expect(response['channel']['color']).to eq 'red'
    expect(response['channel']).not_to include 'age'
    expect(response['channel']).not_to include 'motd'
  end

  it 'can delete' do
    response = @channel.delete
    expect(response).to include 'channel'
    expect(response['channel'].fetch('deleted_at')).not_to eq nil
  end

  it 'can truncate' do
    response = @channel.truncate
    expect(response).to include 'channel'
  end

  it 'can truncate with message' do
    text = SecureRandom.uuid.to_s
    @channel.truncate(message: { text: text, user_id: @random_user[:id] })

    loop_times 60 do
      channel_state = @channel.query
      expect(channel_state).to include 'messages'
      expect(channel_state['messages'][0]['text']).to eq(text)
    end
  end

  it 'can add members' do
    response = @channel.remove_members([@random_users[0][:id], @random_users[1][:id]])
    expect(response['members'].length).to eq 0

    @channel.add_members([@random_users[0][:id]])
    response = @channel.add_members([@random_users[1][:id]], hide_history: true)
    expect(response['members'].length).to eq 2
    response['members']&.each do |m|
      expect(m.fetch('is_moderator', false)).to be false
    end
  end

  it 'can invite members' do
    response = @channel.remove_members([@random_user[:id]])
    expect(response['members'].length).to eq 0

    response = @channel.invite_members([@random_user[:id]])
    expect(response['members'].length).to eq 1
    expect(response['members'][0].fetch('invited', false)).to be true
  end

  it 'can accept invitation' do
    @channel.remove_members([@random_user[:id]])
    @channel.invite_members([@random_user[:id]])

    @channel.accept_invite(@random_user[:id])
  end

  it 'can reject invitation' do
    @channel.remove_members([@random_user[:id]])
    @channel.invite_members([@random_user[:id]])

    @channel.reject_invite(@random_user[:id])
  end

  it 'can add moderators' do
    response = @channel.add_moderators([@random_user[:id]])
    expect(response['members'][0]['is_moderator']).to be true

    response = @channel.demote_moderators([@random_user[:id]])
    expect(response['members'][0].fetch('is_moderator', false)).to be false
  end

  it 'can mark messages as read' do
    response = @channel.mark_read(@random_user[:id])
    expect(response).to include 'event'
    expect(response['event']['type']).to eq 'message.read'
  end

  it 'can get replies' do
    msg = @channel.send_message({ 'text' => 'hi' }, @random_user[:id])
    response = @channel.get_replies(msg['message']['id'])
    expect(response).to include 'messages'
    expect(response['messages'].length).to eq 0
    (1..10).each do |i|
      @channel.send_message(
        { 'text' => 'hi', 'index' => i, 'parent_id' => msg['message']['id'] },
        @random_user[:id]
      )
    end
    response = @channel.get_replies(msg['message']['id'])
    expect(response).to include 'messages'
    expect(response['messages'].length).to eq 10
  end

  it 'can get reactions' do
    msg = @channel.send_message({ 'text' => 'hi' }, @random_user[:id])
    response = @channel.get_reactions(msg['message']['id'])
    expect(response).to include 'reactions'
    expect(response['reactions'].length).to eq 0

    @channel.send_reaction(msg['message']['id'], { 'type' => 'love', 'count' => 42 }, @random_user[:id])
    @channel.send_reaction(msg['message']['id'], { 'type' => 'clap' }, @random_user[:id])

    response = @channel.get_reactions(msg['message']['id'])
    expect(response['reactions'].length).to eq 2

    response = @channel.get_reactions(msg['message']['id'], offset: 1)
    expect(response['reactions'].length).to eq 1
    expect(response['reactions'][0]['count']).to eq 42
  end

  it 'hides\shows channel for user' do
    @channel.hide(@random_user[:id])
    @channel.show(@random_user[:id])
  end

  file = ''
  it 'can send file' do
    response = @channel.send_file("#{__dir__}/data/helloworld.txt", @random_user, 'text/plain')
    expect(response).to have_key('file')
    file = response['file']
  end

  it 'delete file' do
    @channel.delete_file(file)
  end

  image = ''
  it 'can send image' do
    response = @channel.send_image("#{__dir__}/data/helloworld.jpg", @random_user, 'image/jpeg')
    expect(response).to have_key('file')
    image = response['file']
  end

  it 'delete image' do
    @channel.delete_image(image)
  end

  it 'query members' do
    response = @channel.query_members
    expect(response['members'].length).to eq 0

    members = []
    @random_users&.each do |u|
      members << u[:id]
    end
    @channel.add_members(members)

    response = @channel.query_members(sort: { name: 1 })
    expect(response['members'].length).to eq 2

    got_members = []
    response['members']&.each do |m|
      got_members << m['user']['id']
    end
    expect(got_members).to eq members.reverse

    response = @channel.query_members(limit: 1)
    expect(response['members'].length).to eq 1
  end
end
