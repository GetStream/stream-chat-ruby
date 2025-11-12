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
    @created_users = []
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid, name: 'b' }, { id: SecureRandom.uuid, name: 'a' }]
    @random_user = { id: SecureRandom.uuid }

    users_to_insert = [@random_users[0], @random_users[1], @random_user]

    @created_users.push(*users_to_insert.map { |u| u[:id] })
    @client.upsert_users(users_to_insert)

    @channel = @client.channel('messaging', channel_id: SecureRandom.uuid, data: { test: true, language: 'ruby' })
    @channel.create(@random_user[:id])
  end

  after(:each) do
    @channel.delete
  rescue StreamChat::StreamAPIException
    # if the channel is already deleted by the test, we can ignore the error
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

    history_cutoff = DateTime.now - 1
    @channel.add_members([@random_users[0][:id]], hide_history_before: history_cutoff)
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
    @channel.add_members([@random_user[:id]])
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

  it 'send message with pending metadata' do
    options = {
      is_pending_message: true,
      pending_message_metadata: {
        metadata: 'some_data'
      }
    }
    msg = @channel.send_message({ text: 'hi' }, @random_user[:id], **options)
    response = @client.get_message(msg['message']['id'])
    expect(response['message']).not_to be_empty
    expect(response['pending_message_metadata']['metadata']).to eq 'some_data'
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

    response = @channel.query_members(filter_conditions: { notifications_muted: true })
    expect(response['members'].length).to eq 2
  end

  it 'can pin and unpin a channel' do
    @channel.add_members([@random_users[0][:id]])
    @channel.add_members([@random_users[1][:id]])

    # Pin the channel
    now = Time.now
    response = @channel.pin(@random_users[0][:id])
    expect(response['channel_member']['pinned_at']).not_to be_nil
    expect(Time.parse(response['channel_member']['pinned_at']).to_i).to be >= now.to_i

    # Query for pinned channel
    response = @client.query_channels({ 'pinned' => true, 'cid' => @channel.cid }, sort: nil, user_id: @random_users[0][:id])
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['cid']).to eq @channel.cid

    # Unpin the channel
    response = @channel.unpin(@random_users[0][:id])
    expect(response['channel_member']).not_to have_key('pinned_at')

    # Query for unpinned channel
    response = @client.query_channels({ 'pinned' => false, 'cid' => @channel.cid }, sort: nil, user_id: @random_users[0][:id])
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['cid']).to eq @channel.cid
  end

  it 'can archive and unarchive a channel' do
    @channel.add_members([@random_users[0][:id]])
    @channel.add_members([@random_users[1][:id]])

    # Pin the channel
    now = Time.now
    response = @channel.archive(@random_users[0][:id])
    expect(response['channel_member']['archived_at']).not_to be_nil
    expect(Time.parse(response['channel_member']['archived_at']).to_i).to be >= now.to_i

    # Query for archived channel
    response = @client.query_channels({ 'archived' => true, 'cid' => @channel.cid }, sort: nil, user_id: @random_users[0][:id])
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['cid']).to eq @channel.cid

    # Unarchive the channel
    response = @channel.unarchive(@random_users[0][:id])
    expect(response['channel_member']).not_to have_key('archived_at')

    # Query for unarchived channel
    response = @client.query_channels({ 'archived' => false, 'cid' => @channel.cid }, sort: nil, user_id: @random_users[0][:id])
    expect(response['channels'].length).to eq 1
    expect(response['channels'][0]['channel']['cid']).to eq @channel.cid
  end

  it 'can update channel member partially' do
    @channel.add_members([@random_users[0][:id]])

    # Test setting a field
    response = @channel.update_member_partial(@random_users[0][:id], set: { 'hat' => 'blue' })
    expect(response['channel_member']['hat']).to eq 'blue'

    # Test setting and unsetting fields
    response = @channel.update_member_partial(@random_users[0][:id], set: { 'color' => 'red' }, unset: ['hat'])
    expect(response['channel_member']['color']).to eq 'red'
    expect(response['channel_member']).not_to have_key('hat')
  end

  it 'can send message with restricted visibility' do
    # Add users as members before testing restricted visibility
    @channel.add_members([@random_users[0][:id], @random_users[1][:id]])

    # Send a message that's only visible to specific users
    msg = @channel.send_message(
      {
        'text' => 'secret message',
        'restricted_visibility' => [@random_users[0][:id], @random_users[1][:id]]
      },
      @random_user[:id]
    )

    # Verify the message was sent successfully
    expect(msg).to include 'message'
    expect(msg['message']['text']).to eq 'secret message'

    # Verify the restricted visibility
    expect(msg['message']['restricted_visibility']).to match_array([@random_users[0][:id], @random_users[1][:id]])
  end

  it 'can update message with restricted visibility' do
    # Add users as members before testing restricted visibility
    @channel.add_members([@random_users[0][:id], @random_users[1][:id]])

    # First send a regular message
    msg = @channel.send_message(
      {
        'text' => 'original message'
      },
      @random_user[:id]
    )

    # Update the message with restricted visibility
    updated_msg = @client.update_message(
      {
        'id' => msg['message']['id'],
        'text' => 'updated secret message',
        'restricted_visibility' => [@random_users[0][:id], @random_users[1][:id]],
        'user' => { 'id' => @random_user[:id] }
      }
    )

    # Verify the message was updated successfully
    expect(updated_msg).to include 'message'
    expect(updated_msg['message']['text']).to eq 'updated secret message'

    # Verify the restricted visibility
    expect(updated_msg['message']['restricted_visibility']).to match_array([@random_users[0][:id], @random_users[1][:id]])
  end

  it 'can update message partially with restricted visibility' do
    # Add users as members before testing restricted visibility
    @channel.add_members([@random_users[0][:id], @random_users[1][:id]])

    # First send a regular message
    msg = @channel.send_message(
      {
        'text' => 'original message',
        'custom_field' => 'original value'
      },
      @random_user[:id]
    )

    # Partially update the message with restricted visibility
    updated_msg = @client.update_message_partial(
      msg['message']['id'],
      {
        set: {
          text: 'partially updated secret message',
          restricted_visibility: [@random_users[0][:id], @random_users[1][:id]]
        },
        unset: ['custom_field']
      },
      user_id: @random_user[:id]
    )

    # Verify the message was updated successfully
    expect(updated_msg).to include 'message'
    expect(updated_msg['message']['text']).to eq 'partially updated secret message'

    # Verify the restricted visibility was set
    expect(updated_msg['message']['restricted_visibility']).to match_array([@random_users[0][:id], @random_users[1][:id]])

    # Verify the custom field was unset
    expect(updated_msg['message']).not_to include 'custom_field'
  end

  it 'can create draft message' do
    draft_message = { 'text' => 'This is a draft message' }
    response = @channel.create_draft(draft_message, @random_user[:id])

    expect(response).to include 'draft'
    expect(response['draft']['message']['text']).to eq 'This is a draft message'
    expect(response['draft']['channel_cid']).to eq @channel.cid
  end

  it 'can get draft message' do
    # First create a draft
    draft_message = { 'text' => 'This is a draft to retrieve' }
    @channel.create_draft(draft_message, @random_user[:id])

    # Then get the draft
    response = @channel.get_draft(@random_user[:id])

    expect(response).to include 'draft'
    expect(response['draft']['message']['text']).to eq 'This is a draft to retrieve'
    expect(response['draft']['channel_cid']).to eq @channel.cid
  end

  it 'can delete draft message' do
    # First create a draft
    draft_message = { 'text' => 'This is a draft to delete' }
    @channel.create_draft(draft_message, @random_user[:id])

    # Then delete the draft
    @channel.delete_draft(@random_user[:id])

    # Verify it's deleted by trying to get it
    expect { @channel.get_draft(@random_user[:id]) }.to raise_error(StreamChat::StreamAPIException)
  end

  it 'can create and manage thread draft' do
    # First create a parent message
    msg = @channel.send_message({ 'text' => 'Parent message' }, @random_user[:id])
    parent_id = msg['message']['id']

    # Create a draft reply
    draft_reply = { 'text' => 'This is a draft reply', 'parent_id' => parent_id }
    response = @channel.create_draft(draft_reply, @random_user[:id])

    expect(response).to include 'draft'
    expect(response['draft']['message']['text']).to eq 'This is a draft reply'
    expect(response['draft']['parent_id']).to eq parent_id

    # Get the draft reply
    response = @channel.get_draft(@random_user[:id], parent_id: parent_id)

    expect(response).to include 'draft'
    expect(response['draft']['message']['text']).to eq 'This is a draft reply'
    expect(response['draft']['parent_id']).to eq parent_id

    # Delete the draft reply
    @channel.delete_draft(@random_user[:id], parent_id: parent_id)

    # Verify it's deleted
    expect { @channel.get_draft(@random_user[:id], parent_id: parent_id) }.to raise_error(StreamChat::StreamAPIException)
  end

  it 'can add and remove filter tags' do
    tags = %w[urgent bug]
    # Add tags
    response = @channel.add_filter_tags(tags)
    expect(response).to include 'channel'

    # Ensure tags are set
    response = @channel.query
    expect(response['channel']['filter_tags']).to match_array(tags)

    # Remove one tag
    @channel.remove_filter_tags(['urgent'])
    response = @channel.query
    expect(response['channel']['filter_tags']).to match_array(['bug'])
  end
end
