# frozen_string_literal: true

require 'stream-chat/errors'
require 'stream-chat/util'

module StreamChat
  class Channel # rubocop:todo Metrics/ClassLength # rubocop:todo Style/Documentation
    attr_reader :id
    attr_reader :channel_type
    attr_reader :custom_data
    attr_reader :members

    def initialize(client, channel_type, channel_id = nil, custom_data = nil)
      @channel_type = channel_type
      @id = channel_id
      @client = client
      @custom_data = custom_data
      @custom_data = {} if @custom_data.nil?
    end

    def url
      raise StreamChannelException, 'channel does not have an id' if @id.nil?

      "channels/#{@channel_type}/#{@id}"
    end

    def send_message(message, user_id)
      payload = { message: add_user_id(message, user_id) }
      @client.post("#{url}/message", data: payload)
    end

    def send_event(event, user_id)
      payload = { 'event' => add_user_id(event, user_id) }
      @client.post("#{url}/event", data: payload)
    end

    def send_reaction(message_id, reaction, user_id)
      payload = { reaction: add_user_id(reaction, user_id) }
      @client.post("messages/#{message_id}/reaction", data: payload)
    end

    def delete_reaction(message_id, reaction_type, user_id)
      @client.delete(
        "messages/#{message_id}/reaction/#{reaction_type}",
        params: { user_id: user_id }
      )
    end

    def create(user_id)
      @custom_data['created_by'] = { id: user_id }
      query(watch: false, state: false, presence: false)
    end

    def query(**options)
      payload = { state: true, data: @custom_data }.merge(options)
      url = "channels/#{@channel_type}"
      url = "#{url}/#{@id}" unless @id.nil?

      state = @client.post("#{url}/query", data: payload)
      @id = state['channel']['id'] if @id.nil?
      state
    end

    def query_members(filter_conditions = {}, sort: nil, **options)
      params = {}.merge(options).merge({
                                         id: @id,
                                         type: @channel_type,
                                         filter_conditions: filter_conditions,
                                         sort: get_sort_fields(sort)
                                       })

      if @id == '' && @members.length.positive?
        params['members'] = []
        @members&.each do |m|
          params['members'] << m['user'].nil? ? m['user_id'] : m['user']['id']
        end
      end

      @client.get('members', params: { payload: params.to_json })
    end

    def update(channel_data, update_message = nil)
      payload = { data: channel_data, message: update_message }
      @client.post(url, data: payload)
    end

    def update_partial(set = nil, unset = nil)
      raise StreamChannelException, 'set or unset is needed' if set.nil? && unset.nil?

      payload = { set: set, unset: unset }
      @client.patch(url, data: payload)
    end

    def delete
      @client.delete(url)
    end

    def truncate(**options)
      @client.post("#{url}/truncate", data: options)
    end

    def add_members(user_ids)
      @client.post(url, data: { add_members: user_ids })
    end

    def invite_members(user_ids)
      @client.post(url, data: { invites: user_ids })
    end

    def add_moderators(user_ids)
      @client.post(url, data: { add_moderators: user_ids })
    end

    def remove_members(user_ids)
      @client.post(url, data: { remove_members: user_ids })
    end

    def assign_roles(members, message = nil)
      @client.post(url, data: { assign_roles: members, message: message })
    end

    def demote_moderators(user_ids)
      @client.post(url, data: { demote_moderators: user_ids })
    end

    def mark_read(user_id, **options)
      payload = add_user_id(options, user_id)
      @client.post("#{url}/read", data: payload)
    end

    def get_replies(parent_id, **options)
      @client.get("messages/#{parent_id}/replies", params: options)
    end

    def get_reactions(message_id, **options)
      @client.get("messages/#{message_id}/reactions", params: options)
    end

    def ban_user(user_id, **options)
      @client.ban_user(user_id, type: @channel_type, id: @id, **options)
    end

    def unban_user(user_id)
      @client.unban_user(user_id, type: @channel_type, id: @id)
    end

    def hide(user_id)
      @client.post("#{url}/hide", data: { user_id: user_id })
    end

    def show(user_id)
      @client.post("#{url}/show", data: { user_id: user_id })
    end

    def send_file(url, user, content_type = nil)
      @client.send_file("#{self.url}/file", url, user, content_type)
    end

    def send_image(url, user, content_type = nil)
      @client.send_file("#{self.url}/image", url, user, content_type)
    end

    def delete_file(url)
      @client.delete("#{self.url}/file", params: { url: url })
    end

    def delete_image(url)
      @client.delete("#{self.url}/image", params: { url: url })
    end

    private

    def add_user_id(payload, user_id)
      payload.merge({ user: { id: user_id } })
    end
  end
end
