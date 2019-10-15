require 'securerandom'
require 'stream-chat'

describe StreamChat::Channel do
  before(:all) do
    @client = StreamChat::Client.new(ENV['STREAM_CHAT_API_KEY'], ENV['STREAM_CHAT_API_SECRET'], {base_url: ENV['STREAM_CHAT_API_HOST']})
  end

  before(:each) do
    @random_users = [{id: SecureRandom.uuid}, {id: SecureRandom.uuid}]
    @client.update_users(@random_users)

    @random_user = {id: SecureRandom.uuid}
    response = @client.update_user(@random_user)
    expect(response).to include 'users'
    expect(response['users']).to include @random_user[:id]

    @channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { 'test' => true, 'language' => 'ruby'})
    @channel.create(@random_user[:id])
  end

  it 'can create channel without id' do
    channel = @client.channel('messaging', data: {'members' => @random_users.map { |u| u[:id] }})
    expect(channel.id).to eq nil

    channel.create(@random_users[0][:id])
    expect(channel.id).not_to eq nil
  end

  it 'can send events' do
    response = @channel.send_event({'type' => 'typing.start'}, @random_user[:id])
    expect(response).to include 'event'
    expect(response['event']['type']).to eq 'typing.start'
  end

  it 'can send reactions' do
    msg = @channel.send_message({'text' => 'hi'}, @random_user[:id])
    response = @channel.send_reaction(msg['message']['id'], {'type' => 'love'}, @random_user[:id])
    expect(response).to include 'message'
    expect(response['message']['latest_reactions'].length).to eq 1
    expect(response['message']['latest_reactions'][0]['type']).to eq 'love'
  end

  it 'can delete a reaction' do
    msg = @channel.send_message({'text' => 'hi'}, @random_user[:id])
    @channel.send_reaction(msg['message']['id'], {'type' => 'love'}, @random_user[:id])
    response = @channel.delete_reaction(msg['message']['id'], 'love', @random_user[:id])
    expect(response).to include 'message'
    expect(response['message']['latest_reactions'].length).to eq 0
  end

  it 'can update metadata' do
    response = @channel.update({'motd' => 'one apple a day...'})
    expect(response).to include 'channel'
    expect(response['channel']['motd']).to eq 'one apple a day...'
  end

  it 'can delete ' do
    response = @channel.delete()
    expect(response).to include 'channel'
    expect(response['channel'].fetch('deleted_at')).not_to eq nil
  end

  it 'can truncate' do
    response = @channel.truncate()
    expect(response).to include 'channel'
  end

  it 'can add members' do
    response = @channel.remove_members([@random_user[:id]])
    expect(response['members'].length).to eq 0

    response = @channel.add_members([@random_user[:id]])
    expect(response['members'].length).to eq 1
    expect(response['members'][0].fetch('is_moderator', false)).to be false
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
    msg = @channel.send_message({'text' => 'hi'}, @random_user[:id])
    response = @channel.get_replies(msg['message']['id'])
    expect(response).to include 'messages'
    expect(response['messages'].length).to eq 0
    for i in 1..10
      @channel.send_message(
        {'text' => 'hi', 'index' => i, 'parent_id' => msg['message']['id']},
        @random_user[:id]
      )
    end
    response = @channel.get_replies(msg['message']['id'])
    expect(response).to include 'messages'
    expect(response['messages'].length).to eq 10
  end

  it 'can get reactions' do
    msg = @channel.send_message({'text' => 'hi'}, @random_user[:id])
    response = @channel.get_reactions(msg['message']['id'])
    expect(response).to include 'reactions'
    expect(response['reactions'].length).to eq 0

    @channel.send_reaction(msg['message']['id'], {'type' => 'love', 'count' => 42}, @random_user[:id])
    @channel.send_reaction(msg['message']['id'], {'type' => 'clap'}, @random_user[:id])

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
end

