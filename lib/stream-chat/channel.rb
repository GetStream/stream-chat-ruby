# typed: strict
# frozen_string_literal: true

require 'stream-chat/errors'
require 'stream-chat/util'
require 'stream-chat/types'

module StreamChat
  class Channel
    extend T::Sig
    T::Configuration.default_checked_level = :never
    # For now we disable runtime type checks.
    # We will enable it with a major bump in the future,
    # but for now, let's just run a static type check.

    sig { returns(T.nilable(String)) }
    attr_reader :id

    sig { returns(String) }
    attr_reader :channel_type

    sig { returns(StringKeyHash) }
    attr_reader :custom_data

    sig { returns(T::Array[StringKeyHash]) }
    attr_reader :members

    sig { params(client: Client, channel_type: String, channel_id: T.nilable(String), custom_data: T.nilable(StringKeyHash)).void }
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

    sig { params(message_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def get_messages(message_ids)
      @client.get("#{url}/messages", params: { 'ids' => message_ids.join(',') })
    end

    sig { params(message: StringKeyHash, user_id: String).returns(StreamChat::StreamResponse) }
    def send_message(message, user_id)
      payload = { message: add_user_id(message, user_id) }
      @client.post("#{url}/message", data: payload)
    end

    sig { params(event: StringKeyHash, user_id: String).returns(StreamChat::StreamResponse) }
    def send_event(event, user_id)
      payload = { 'event' => add_user_id(event, user_id) }
      @client.post("#{url}/event", data: payload)
    end

    sig { params(message_id: String, reaction: StringKeyHash, user_id: String).returns(StreamChat::StreamResponse) }
    def send_reaction(message_id, reaction, user_id)
      payload = { reaction: add_user_id(reaction, user_id) }
      @client.post("messages/#{message_id}/reaction", data: payload)
    end

    sig { params(message_id: String, reaction_type: String, user_id: String).returns(StreamChat::StreamResponse) }
    def delete_reaction(message_id, reaction_type, user_id)
      @client.delete(
        "messages/#{message_id}/reaction/#{reaction_type}",
        params: { user_id: user_id }
      )
    end

    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def create(user_id)
      @custom_data['created_by'] = { id: user_id }
      query(watch: false, state: false, presence: false)
    end

    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def query(**options)
      payload = { state: true, data: @custom_data }.merge(options)
      url = "channels/#{@channel_type}"
      url = "#{url}/#{@id}" unless @id.nil?

      state = @client.post("#{url}/query", data: payload)
      @id = state['channel']['id'] if @id.nil?
      state
    end

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

    sig { params(channel_data: T.nilable(StringKeyHash), update_message: T.nilable(StringKeyHash), options: T.untyped).returns(StreamChat::StreamResponse) }
    def update(channel_data, update_message = nil, **options)
      payload = { data: channel_data, message: update_message }.merge(options)
      @client.post(url, data: payload)
    end

    sig { params(set: T.nilable(StringKeyHash), unset: T.nilable(T::Array[String])).returns(StreamChat::StreamResponse) }
    def update_partial(set = nil, unset = nil)
      raise StreamChannelException, 'set or unset is needed' if set.nil? && unset.nil?

      payload = { set: set, unset: unset }
      @client.patch(url, data: payload)
    end

    sig { returns(StreamChat::StreamResponse) }
    def delete
      @client.delete(url)
    end

    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def truncate(**options)
      @client.post("#{url}/truncate", data: options)
    end

    sig { params(user_id: String, expiration: T.nilable(Integer)).returns(StreamChat::StreamResponse) }
    def mute(user_id, expiration = nil)
      data = { user_id: user_id, channel_cid: @cid }
      data['expiration'] = expiration if expiration
      @client.post('moderation/mute/channel', data: data)
    end

    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def unmute(user_id)
      @client.post('moderation/unmute/channel', data: { 'user_id' => user_id, 'channel_cid' => @cid })
    end

    sig { params(user_ids: T::Array[String], options: T.untyped).returns(StreamChat::StreamResponse) }
    def add_members(user_ids, **options)
      payload = options.merge({ add_members: user_ids })
      update(nil, nil, **payload)
    end

    sig { params(user_ids: T::Array[String], options: T.untyped).returns(StreamChat::StreamResponse) }
    def invite_members(user_ids, **options)
      payload = options.merge({ invites: user_ids })
      update(nil, nil, **payload)
    end

    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def accept_invite(user_id, **options)
      payload = options.merge({ user_id: user_id, accept_invite: true })
      update(nil, nil, **payload)
    end

    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def reject_invite(user_id, **options)
      payload = options.merge({ user_id: user_id, reject_invite: true })
      update(nil, nil, **payload)
    end

    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def add_moderators(user_ids)
      update(nil, nil, add_moderators: user_ids)
    end

    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def remove_members(user_ids)
      update(nil, nil, remove_members: user_ids)
    end

    sig { params(members: T::Array[StringKeyHash], message: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def assign_roles(members, message = nil)
      update(nil, message, assign_roles: members)
    end

    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def demote_moderators(user_ids)
      update(nil, nil, demote_moderators: user_ids)
    end

    sig { params(user_id: String, options: StringKeyHash).returns(StreamChat::StreamResponse) }
    def mark_read(user_id, **options)
      payload = add_user_id(options, user_id)
      @client.post("#{url}/read", data: payload)
    end

    sig { params(parent_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def get_replies(parent_id, **options)
      @client.get("messages/#{parent_id}/replies", params: options)
    end

    sig { params(message_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def get_reactions(message_id, **options)
      @client.get("messages/#{message_id}/reactions", params: options)
    end

    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def ban_user(user_id, **options)
      @client.ban_user(user_id, type: @channel_type, id: @id, **options)
    end

    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def unban_user(user_id)
      @client.unban_user(user_id, type: @channel_type, id: @id)
    end

    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def hide(user_id)
      @client.post("#{url}/hide", data: { user_id: user_id })
    end

    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def show(user_id)
      @client.post("#{url}/show", data: { user_id: user_id })
    end

    sig { params(url: String, user: StringKeyHash, content_type: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def send_file(url, user, content_type = nil)
      @client.send_file("#{self.url}/file", url, user, content_type)
    end

    sig { params(url: String, user: StringKeyHash, content_type: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def send_image(url, user, content_type = nil)
      @client.send_file("#{self.url}/image", url, user, content_type)
    end

    sig { params(url: String).returns(StreamChat::StreamResponse) }
    def delete_file(url)
      @client.delete("#{self.url}/file", params: { url: url })
    end

    sig { params(url: String).returns(StreamChat::StreamResponse) }
    def delete_image(url)
      @client.delete("#{self.url}/image", params: { url: url })
    end

    private

    sig { params(payload: StringKeyHash, user_id: String).returns(StringKeyHash) }
    def add_user_id(payload, user_id)
      payload.merge({ user: { id: user_id } })
    end
  end
end
