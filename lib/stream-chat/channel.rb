# typed: strict
# frozen_string_literal: true

require 'stream-chat/client'
require 'stream-chat/errors'
require 'stream-chat/util'
require 'stream-chat/types'

module StreamChat
  class Channel
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :id

    sig { returns(String) }
    attr_reader :channel_type

    sig { returns(String) }
    attr_reader :cid

    sig { returns(StringKeyHash) }
    attr_reader :custom_data

    sig { returns(T::Array[StringKeyHash]) }
    attr_reader :members

    sig { params(client: StreamChat::Client, channel_type: String, channel_id: T.nilable(String), custom_data: T.nilable(StringKeyHash)).void }
    def initialize(client, channel_type, channel_id = nil, custom_data = nil)
      @channel_type = channel_type
      @id = channel_id
      @cid = T.let("#{@channel_type}:#{@id}", String)
      @client = client
      @custom_data = T.let(custom_data || {}, StringKeyHash)
      @members = T.let([], T::Array[StringKeyHash])
    end

    sig { returns(String) }
    def url
      raise StreamChannelException, 'channel does not have an id' if @id.nil?

      "channels/#{@channel_type}/#{@id}"
    end

    # Gets multiple messages from the channel.
    sig { params(message_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def get_messages(message_ids)
      @client.get("#{url}/messages", params: { 'ids' => message_ids.join(',') })
    end

    # Sends a message to this channel.
    sig { params(message: StringKeyHash, user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def send_message(message, user_id, **options)
      payload = options.merge({ message: add_user_id(message, user_id) })
      @client.post("#{url}/message", data: payload)
    end

    # Sends an event on this channel.
    sig { params(event: StringKeyHash, user_id: String).returns(StreamChat::StreamResponse) }
    def send_event(event, user_id)
      payload = { 'event' => add_user_id(event, user_id) }
      @client.post("#{url}/event", data: payload)
    end

    # Sends a new reaction to a given message.
    sig { params(message_id: String, reaction: StringKeyHash, user_id: String).returns(StreamChat::StreamResponse) }
    def send_reaction(message_id, reaction, user_id)
      payload = { reaction: add_user_id(reaction, user_id) }
      @client.post("messages/#{message_id}/reaction", data: payload)
    end

    # Delete a reaction from a message.
    sig { params(message_id: String, reaction_type: String, user_id: String).returns(StreamChat::StreamResponse) }
    def delete_reaction(message_id, reaction_type, user_id)
      @client.delete(
        "messages/#{message_id}/reaction/#{reaction_type}",
        params: { user_id: user_id }
      )
    end

    # Creates a channel with the given creator user.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def create(user_id)
      @custom_data['created_by'] = { id: user_id }
      query(watch: false, state: false, presence: false)
    end

    # Creates or returns a channel.
    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def query(**options)
      payload = { state: true, data: @custom_data }.merge(options)
      url = "channels/#{@channel_type}"
      url = "#{url}/#{@id}" unless @id.nil?

      state = @client.post("#{url}/query", data: payload)
      @id = state['channel']['id'] if @id.nil?
      state
    end

    # Refreshes the channel state from the server.
    # Updates the channel's members attribute with fresh data.
    sig { returns(StreamChat::StreamResponse) }
    def refresh_state
      url = "channels/#{@channel_type}/#{@id}/query"
      state = @client.post(url, data: { state: true })

      # Members can be at top level or inside channel object (like Go's updateChannel)
      if state['members'] && !state['members'].empty?
        @members = state['members']
      elsif state['channel'] && state['channel']['members']
        @members = state['channel']['members']
      end
      state
    end

    # Queries members of a channel.
    #
    # The queryMembers endpoint allows you to list and paginate members from a channel. The
    # endpoint supports filtering on numerous criteria to efficiently return members information.
    # This endpoint is useful for channels that have large lists of members and
    # you want to search members or if you want to display the full list of members for a channel.
    sig { params(filter_conditions: StringKeyHash, sort: T.nilable(T::Hash[String, Integer]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_members(filter_conditions = {}, sort: nil, **options)
      params = {}.merge(options).merge({
                                         id: @id,
                                         type: @channel_type,
                                         filter_conditions: filter_conditions,
                                         sort: StreamChat.get_sort_fields(sort)
                                       })

      if @id == '' && @members.length.positive?
        params['members'] = []
        @members.each do |m|
          params['members'] << m['user'].nil? ? m['user_id'] : m['user']['id']
        end
      end

      @client.get('members', params: { payload: params.to_json })
    end

    # Updates a channel.
    sig { params(channel_data: T.nilable(StringKeyHash), update_message: T.nilable(StringKeyHash), options: T.untyped).returns(StreamChat::StreamResponse) }
    def update(channel_data, update_message = nil, **options)
      payload = { data: channel_data, message: update_message }.merge(options)
      @client.post(url, data: payload)
    end

    # Updates a channel partially.
    sig { params(set: T.nilable(StringKeyHash), unset: T.nilable(T::Array[String])).returns(StreamChat::StreamResponse) }
    def update_partial(set = nil, unset = nil)
      raise StreamChannelException, 'set or unset is needed' if set.nil? && unset.nil?

      payload = { set: set, unset: unset }
      @client.patch(url, data: payload)
    end

    # Deletes a channel.
    sig { returns(StreamChat::StreamResponse) }
    def delete
      @client.delete(url)
    end

    # Removes all messages from the channel.
    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def truncate(**options)
      @client.post("#{url}/truncate", data: options)
    end

    # Mutes a channel.
    #
    # Messages added to a muted channel will not trigger push notifications, nor change the
    # unread count for the users that muted it. By default, mutes stay in place indefinitely
    # until the user removes it; however, you can optionally set an expiration time. The list
    # of muted channels and their expiration time is returned when the user connects.
    sig { params(user_id: String, expiration: T.nilable(Integer)).returns(StreamChat::StreamResponse) }
    def mute(user_id, expiration = nil)
      data = { user_id: user_id, channel_cid: @cid }
      data['expiration'] = expiration if expiration
      @client.post('moderation/mute/channel', data: data)
    end

    # Unmutes a channel.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def unmute(user_id)
      @client.post('moderation/unmute/channel', data: { 'user_id' => user_id, 'channel_cid' => @cid })
    end

    # Pins a channel for a user.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def pin(user_id)
      raise StreamChannelException, 'user ID must not be empty' if user_id.empty?

      payload = {
        set: {
          pinned: true
        }
      }
      @client.patch("#{url}/member/#{CGI.escape(user_id)}", data: payload)
    end

    # Unins a channel for a user.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def unpin(user_id)
      raise StreamChannelException, 'user ID must not be empty' if user_id.empty?

      payload = {
        set: {
          pinned: false
        }
      }
      @client.patch("#{url}/member/#{CGI.escape(user_id)}", data: payload)
    end

    # Archives a channel for a user.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def archive(user_id)
      raise StreamChannelException, 'user ID must not be empty' if user_id.empty?

      payload = {
        set: {
          archived: true
        }
      }
      @client.patch("#{url}/member/#{CGI.escape(user_id)}", data: payload)
    end

    # Archives a channel for a user.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def unarchive(user_id)
      raise StreamChannelException, 'user ID must not be empty' if user_id.empty?

      payload = {
        set: {
          archived: false
        }
      }
      @client.patch("#{url}/member/#{CGI.escape(user_id)}", data: payload)
    end

    # Updates a member partially in the channel.
    sig { params(user_id: String, set: T.nilable(StringKeyHash), unset: T.nilable(T::Array[String])).returns(StreamChat::StreamResponse) }
    def update_member_partial(user_id, set: nil, unset: nil)
      raise StreamChannelException, 'user ID must not be empty' if user_id.empty?
      raise StreamChannelException, 'set or unset is required' if set.nil? && unset.nil?

      payload = { set: set, unset: unset }
      @client.patch("#{url}/member/#{CGI.escape(user_id)}", data: payload)
    end

    # Adds members to the channel.
    sig { params(user_ids: T::Array[String], options: T.untyped).returns(StreamChat::StreamResponse) }
    def add_members(user_ids, **options)
      payload = options.dup
      payload[:hide_history_before] = StreamChat.normalize_timestamp(payload[:hide_history_before]) if payload[:hide_history_before]
      payload = payload.merge({ add_members: user_ids })
      update(nil, nil, **payload)
    end

    # Invites users to the channel.
    sig { params(user_ids: T::Array[String], options: T.untyped).returns(StreamChat::StreamResponse) }
    def invite_members(user_ids, **options)
      payload = options.merge({ invites: user_ids })
      update(nil, nil, **payload)
    end

    # Accepts an invitation to the channel.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def accept_invite(user_id, **options)
      payload = options.merge({ user_id: user_id, accept_invite: true })
      update(nil, nil, **payload)
    end

    # Rejects an invitation to the channel.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def reject_invite(user_id, **options)
      payload = options.merge({ user_id: user_id, reject_invite: true })
      update(nil, nil, **payload)
    end

    # Adds moderators to the channel.
    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def add_moderators(user_ids)
      update(nil, nil, add_moderators: user_ids)
    end

    # Adds filter tags to the channel.
    sig { params(tags: T::Array[String]).returns(StreamChat::StreamResponse) }
    def add_filter_tags(tags)
      update(nil, nil, add_filter_tags: tags)
    end

    # Removes filter tags from the channel.
    sig { params(tags: T::Array[String]).returns(StreamChat::StreamResponse) }
    def remove_filter_tags(tags)
      update(nil, nil, remove_filter_tags: tags)
    end

    # Removes members from the channel.
    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def remove_members(user_ids)
      update(nil, nil, remove_members: user_ids)
    end

    # Assigns roles to members in the channel.
    sig { params(members: T::Array[StringKeyHash], message: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def assign_roles(members, message = nil)
      update(nil, message, assign_roles: members)
    end

    # Demotes moderators in the channel.
    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def demote_moderators(user_ids)
      update(nil, nil, demote_moderators: user_ids)
    end

    # Sends the mark read event for this user, only works if the `read_events` setting is enabled.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def mark_read(user_id, **options)
      payload = add_user_id(options, user_id)
      @client.post("#{url}/read", data: payload)
    end

    # List the message replies for a parent message.
    sig { params(parent_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def get_replies(parent_id, **options)
      @client.get("messages/#{parent_id}/replies", params: options)
    end

    # List the reactions, supports pagination.
    sig { params(message_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def get_reactions(message_id, **options)
      @client.get("messages/#{message_id}/reactions", params: options)
    end

    # Bans a user from this channel.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def ban_user(user_id, **options)
      @client.ban_user(user_id, type: @channel_type, id: @id, **options)
    end

    # Removes the ban for a user on this channel.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def unban_user(user_id)
      @client.unban_user(user_id, type: @channel_type, id: @id)
    end

    # Removes a channel from query channel requests for that user until a new message is added.
    # Use `show` to cancel this operation.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def hide(user_id)
      @client.post("#{url}/hide", data: { user_id: user_id })
    end

    # Shows a previously hidden channel.
    # Use `hide` to hide a channel.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def show(user_id)
      @client.post("#{url}/show", data: { user_id: user_id })
    end

    # Uploads a file.
    #
    # This functionality defaults to using the Stream CDN. If you would like, you can
    # easily change the logic to upload to your own CDN of choice.
    sig { params(url: String, user: StringKeyHash, content_type: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def send_file(url, user, content_type = nil)
      @client.send_file("#{self.url}/file", url, user, content_type)
    end

    # Uploads an image.
    #
    # Stream supported image types are: image/bmp, image/gif, image/jpeg, image/png, image/webp,
    # image/heic, image/heic-sequence, image/heif, image/heif-sequence, image/svg+xml.
    # You can set a more restrictive list for your application if needed.
    # The maximum file size is 100MB.
    sig { params(url: String, user: StringKeyHash, content_type: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def send_image(url, user, content_type = nil)
      @client.send_file("#{self.url}/image", url, user, content_type)
    end

    # Deletes a file by file url.
    sig { params(url: String).returns(StreamChat::StreamResponse) }
    def delete_file(url)
      @client.delete("#{self.url}/file", params: { url: url })
    end

    # Deletes an image by image url.
    sig { params(url: String).returns(StreamChat::StreamResponse) }
    def delete_image(url)
      @client.delete("#{self.url}/image", params: { url: url })
    end

    # Creates or updates a draft message for this channel.
    #
    # @param [StringKeyHash] message The draft message content
    # @param [String] user_id The ID of the user creating/updating the draft
    # @return [StreamChat::StreamResponse]
    sig { params(message: StringKeyHash, user_id: String).returns(StreamChat::StreamResponse) }
    def create_draft(message, user_id)
      payload = { message: add_user_id(message, user_id) }
      @client.post("#{url}/draft", data: payload)
    end

    # Deletes a draft message for this channel.
    #
    # @param [String] user_id The ID of the user deleting the draft
    # @param [String] parent_id Optional parent message ID for thread drafts
    # @return [StreamChat::StreamResponse]
    sig { params(user_id: String, parent_id: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def delete_draft(user_id, parent_id: nil)
      params = { user_id: user_id }
      params[:parent_id] = parent_id if parent_id
      @client.delete("#{url}/draft", params: params)
    end

    # Gets a draft message for this channel.
    #
    # @param [String] user_id The ID of the user getting the draft
    # @param [String] parent_id Optional parent message ID for thread drafts
    # @return [StreamChat::StreamResponse]
    sig { params(user_id: String, parent_id: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def get_draft(user_id, parent_id: nil)
      params = { user_id: user_id }
      params[:parent_id] = parent_id if parent_id
      @client.get("#{url}/draft", params: params)
    end

    private

    sig { params(payload: StringKeyHash, user_id: String).returns(StringKeyHash) }
    def add_user_id(payload, user_id)
      payload.merge({ user: { id: user_id } })
    end
  end
end
