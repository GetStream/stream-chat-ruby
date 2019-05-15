module StreamChat

  class Channel
    attr_reader :id
    attr_reader :channel_type
    attr_reader :custom_data
    
    def initialize(client, channel_type, channel_id=nil, custom_data=nil)
      @channel_type = channel_type
      @id = channel_id
      @client = client
      @custom_data = custom_data
      if @custom_data == nil
        @custom_data = {}
      end
    end

    def url
      if @id == nil
        raise StreamChannelException "channel does not have an id"
      end
      "channels/#{@channel_type}/#{@id}"
    end

    def send_message(message, user_id)
      payload = {"message": add_user_id(message, user_id)}
      @client.post("#{url}/message", data: payload)
    end

    def send_event(event, user_id)
      payload = {'event' => add_user_id(event, user_id)}
      @client.post("#{url}/event", data: payload)
    end

    def send_reaction(message_id, reaction, user_id)
      payload = {"reaction": add_user_id(reaction, user_id)}
      @client.post("messages/#{message_id}/reaction", data: payload)
    end

    def delete_reaction(message_id, reaction_type, user_id)
      @client.delete(
        "messages/#{message_id}/reaction/#{reaction_type}",
        params: {"user_id": user_id}
      )
    end

    def create(user_id)
      @custom_data["created_by"] = {"id": user_id}
      query(watch: false, state: false, presence: false)
    end

    def query(**options)
      payload = {"state": true, "data": @custom_data}.merge(options)
      url = "channels/#{@channel_type}"
      if @id != nil
        url = "#{url}/#{@id}"
      end

      state = @client.post("#{url}/query", data: payload)
      if @id == nil
        @id = state["channel"]["id"]
      end
      state
    end

    def update(channel_data, update_message=nil)
      payload = {"data": channel_data, "message": update_message}
      @client.post(url, data: payload)
    end

    def delete
      @client.delete(url)
    end

    def truncate
      @client.post("#{url}/truncate")
    end

    def add_members(user_ids)
      @client.post(url, data: {"add_members": user_ids})
    end

    def add_moderators(user_ids)
      @client.post(url, data: {"add_moderators": user_ids})
    end

    def remove_members(user_ids)
      @client.post(url, data: {"remove_members": user_ids})
    end

    def demote_moderators(user_ids)
      @client.post(url, data: {"demote_moderators": user_ids})
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

    private
    
    def add_user_id(payload, user_id)
      payload.merge({"user": {"id": user_id}})
    end
    
  end
end
