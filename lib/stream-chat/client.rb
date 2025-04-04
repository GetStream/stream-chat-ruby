# typed: strict
# frozen_string_literal: true

require 'open-uri'
require 'faraday'
require 'faraday/multipart'
require 'faraday/net_http_persistent'
require 'jwt'
require 'time'
require 'sorbet-runtime'
require 'stream-chat/channel'
require 'stream-chat/errors'
require 'stream-chat/stream_response'
require 'stream-chat/version'
require 'stream-chat/util'
require 'stream-chat/types'
require 'stream-chat/moderation'

module StreamChat
  DEFAULT_BLOCKLIST = 'profanity_en_2020_v1'
  SOFT_DELETE = 'soft'
  HARD_DELETE = 'hard'

  class Client
    extend T::Sig

    DEFAULT_BASE_URL = 'https://chat.stream-io-api.com'
    DEFAULT_TIMEOUT = 6.0

    sig { returns(String) }
    attr_reader :api_key

    sig { returns(String) }
    attr_reader :api_secret

    sig { returns(Faraday::Connection) }
    attr_reader :conn

    sig { returns(Moderation) }
    attr_reader :moderation

    # initializes a Stream Chat API Client
    #
    # @param [string] api_key your application api_key
    # @param [string] api_secret your application secret
    # @param [float] timeout the timeout for the http requests
    # @param [Hash] options extra options such as base_url
    #
    # @example initialized the client with a timeout setting
    #   StreamChat::Client.new('my_key', 'my_secret', 3.0)
    #
    sig { params(api_key: String, api_secret: String, timeout: T.nilable(T.any(Float, String)), options: T.untyped).void }
    def initialize(api_key, api_secret, timeout = nil, **options)
      raise ArgumentError, 'api_key and api_secret are required' if api_key.to_s.empty? || api_secret.to_s.empty?

      @api_key = api_key
      @api_secret = api_secret
      @timeout = T.let(timeout&.to_f || DEFAULT_TIMEOUT, Float)
      @auth_token = T.let(JWT.encode({ server: true }, @api_secret, 'HS256'), String)
      @base_url = T.let(options[:base_url] || DEFAULT_BASE_URL, String)
      conn = Faraday.new(@base_url) do |faraday|
        faraday.options[:open_timeout] = @timeout
        faraday.options[:timeout] = @timeout
        faraday.request :multipart
        faraday.adapter :net_http_persistent, pool_size: 5 do |http|
          # AWS load balancer idle timeout is 60 secs, so let's make it 59
          http.idle_timeout = 59
        end
      end
      @conn = T.let(conn, Faraday::Connection)
      @moderation = T.let(Moderation.new(self), Moderation)
    end

    # initializes a Stream Chat API Client from STREAM_KEY and STREAM_SECRET
    # environmental variables. STREAM_CHAT_TIMEOUT and STREAM_CHAT_URL
    # variables are optional.
    # @param [StringKeyHash] options extra options
    sig { params(options: T.untyped).returns(Client) }
    def self.from_env(**options)
      Client.new(ENV.fetch('STREAM_KEY'),
                 ENV.fetch('STREAM_SECRET'),
                 ENV.fetch('STREAM_CHAT_TIMEOUT', DEFAULT_TIMEOUT),
                 base_url: ENV.fetch('STREAM_CHAT_URL', DEFAULT_BASE_URL),
                 **options)
    end

    # Sets the underlying Faraday http client.
    #
    # @param [client] an instance of Faraday::Connection
    sig { params(client: Faraday::Connection).void }
    def set_http_client(client)
      @conn = client
    end

    # Creates a JWT for a user.
    #
    # Stream uses JWT (JSON Web Tokens) to authenticate chat users, enabling them to login.
    # Knowing whether a user is authorized to perform certain actions is managed
    # separately via a role based permissions system.
    # You can set an `exp` (expires at) or `iat` (issued at) claim as well.
    sig { params(user_id: String, exp: T.nilable(Integer), iat: T.nilable(Integer)).returns(String) }
    def create_token(user_id, exp = nil, iat = nil)
      payload = { user_id: user_id }
      payload['exp'] = exp unless exp.nil?
      payload['iat'] = iat unless iat.nil?
      JWT.encode(payload, @api_secret, 'HS256')
    end

    # Updates application settings.
    sig { params(settings: T.untyped).returns(StreamChat::StreamResponse) }
    def update_app_settings(**settings)
      patch('app', data: settings)
    end

    # Returns application settings.
    sig { returns(StreamChat::StreamResponse) }
    def get_app_settings
      get('app')
    end

    # Flags a message.
    #
    # Any user is allowed to flag a message. This triggers the message.flagged
    # webhook event and adds the message to the inbox of your
    # Stream Dashboard Chat Moderation view.
    sig { params(id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def flag_message(id, **options)
      payload = { target_message_id: id }.merge(options)
      post('moderation/flag', data: payload)
    end

    # Unflags a message.
    sig { params(id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def unflag_message(id, **options)
      payload = { target_message_id: id }.merge(options)
      post('moderation/unflag', data: payload)
    end

    # Queries message flags.
    #
    # If you prefer to build your own in app moderation dashboard, rather than use the Stream
    # dashboard, then the query message flags endpoint lets you get flagged messages. Similar
    # to other queries in Stream Chat, you can filter the flags using query operators.
    sig { params(filter_conditions: StringKeyHash, options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_message_flags(filter_conditions, **options)
      params = options.merge({
                               filter_conditions: filter_conditions
                             })
      get('moderation/flags/message', params: { payload: params.to_json })
    end

    # Flags a user.
    sig { params(id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def flag_user(id, **options)
      payload = { target_user_id: id }.merge(options)
      post('moderation/flag', data: payload)
    end

    # Unflags a user.
    sig { params(id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def unflag_user(id, **options)
      payload = { target_user_id: id }.merge(options)
      post('moderation/unflag', data: payload)
    end

    # Queries flag reports.
    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_flag_reports(**options)
      data = { filter_conditions: options }
      post('moderation/reports', data: data)
    end

    # Sends a flag report review.
    sig { params(report_id: String, review_result: String, user_id: String, details: T.untyped).returns(StreamChat::StreamResponse) }
    def review_flag_report(report_id, review_result, user_id, **details)
      data = {
        review_result: review_result,
        user_id: user_id,
        review_details: details
      }
      patch("moderation/reports/#{report_id}", data: data)
    end

    # Returns a message.
    sig { params(id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def get_message(id, **options)
      get("messages/#{id}", params: options)
    end

    # Searches for messages.
    #
    # You can enable and/or disable the search indexing on a per channel basis
    # type through the Stream Dashboard.
    sig { params(filter_conditions: StringKeyHash, query: T.any(String, StringKeyHash), sort: T.nilable(T::Hash[String, Integer]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def search(filter_conditions, query, sort: nil, **options)
      offset = T.cast(options[:offset], T.nilable(Integer))
      next_value = options[:next]
      raise ArgumentError, 'cannot use offset with next or sort parameters' if offset&.positive? && (next_value || (!sort.nil? && !sort.empty?))

      to_merge = {
        filter_conditions: filter_conditions,
        sort: StreamChat.get_sort_fields(sort)
      }
      if query.is_a? String
        to_merge[:query] = query
      else
        to_merge[:message_filter_conditions] = query
      end
      get('search', params: { payload: options.merge(to_merge).to_json })
    end

    # @deprecated Use {#upsert_users} instead.
    sig { params(users: T::Array[StringKeyHash]).returns(StreamChat::StreamResponse) }
    def update_users(users)
      warn '[DEPRECATION] `update_users` is deprecated.  Please use `upsert_users` instead.'
      upsert_users(users)
    end

    # @deprecated Use {#upsert_user} instead.
    sig { params(user: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update_user(user)
      warn '[DEPRECATION] `update_user` is deprecated.  Please use `upsert_user` instead.'
      upsert_user(user)
    end

    # Creates or updates users.
    sig { params(users: T::Array[StringKeyHash]).returns(StreamChat::StreamResponse) }
    def upsert_users(users)
      payload = {}
      users.each do |user|
        id = user[:id] || user['id']
        raise ArgumentError, 'user must have an id' unless id

        payload[id] = user
      end
      post('users', data: { users: payload })
    end

    # Creates or updates a user.
    sig { params(user: StringKeyHash).returns(StreamChat::StreamResponse) }
    def upsert_user(user)
      upsert_users([user])
    end

    # Updates multiple users partially.
    sig { params(updates: T::Array[StringKeyHash]).returns(StreamChat::StreamResponse) }
    def update_users_partial(updates)
      patch('users', data: { users: updates })
    end

    # Updates a single user partially.
    sig { params(update: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update_user_partial(update)
      update_users_partial([update])
    end

    # Deletes a user synchronously.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def delete_user(user_id, **options)
      delete("users/#{user_id}", params: options)
    end

    # Restores a user synchronously.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def restore_user(user_id)
      post('users/restore', data: { user_ids: [user_id] })
    end

    # Restores users synchronously.
    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def restore_users(user_ids)
      post('users/restore', data: { user_ids: user_ids })
    end

    # Deactivates a user.
    # Deactivated users cannot connect to Stream Chat, and can't send or receive messages.
    # To reactivate a user, use `reactivate_user` method.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def deactivate_user(user_id, **options)
      post("users/#{user_id}/deactivate", params: options)
    end

    # Deactivates a users
    sig { params(user_ids: T::Array[String], options: T.untyped).returns(StreamChat::StreamResponse) }
    def deactivate_users(user_ids, **options)
      raise ArgumentError, 'user_ids should not be empty' if user_ids.empty?

      post("users/deactivate", data: { user_ids: user_ids, **options })
    end

    # Reactivates a deactivated user. Use deactivate_user to deactivate a user.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def reactivate_user(user_id, **options)
      post("users/#{user_id}/reactivate", params: options)
    end

    # Exports a user. It exports a user and returns an object
    # containing all of it's data.
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def export_user(user_id, **options)
      get("users/#{user_id}/export", params: options)
    end

    # Bans a user. Users can be banned from an app entirely or from a channel.
    # When a user is banned, they will not be allowed to post messages until the
    # ban is removed or expired but will be able to connect to Chat and to channels as before.
    # To unban a user, use `unban_user` method.
    sig { params(target_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def ban_user(target_id, **options)
      payload = { target_user_id: target_id }.merge(options)
      post('moderation/ban', data: payload)
    end

    # Unbans a user.
    # To ban a user, use `ban_user` method.
    sig { params(target_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def unban_user(target_id, **options)
      params = { target_user_id: target_id }.merge(options)
      delete('moderation/ban', params: params)
    end

    # Shadow ban a user.
    # When a user is shadow banned, they will still be allowed to post messages,
    # but any message sent during the will only be visible to the messages author
    # and invisible to other users of the App.
    # To remove a shadow ban, use `remove_shadow_ban` method.
    sig { params(target_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def shadow_ban(target_id, **options)
      payload = { target_user_id: target_id, shadow: true }.merge(options)
      post('moderation/ban', data: payload)
    end

    # Removes a shadow ban of a user.
    # To shadow ban a user, use `shadow_ban` method.
    sig { params(target_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def remove_shadow_ban(target_id, **options)
      params = { target_user_id: target_id, shadow: true }.merge(options)
      delete('moderation/ban', params: params)
    end

    # Mutes a user.
    sig { params(target_id: String, user_id: String).returns(StreamChat::StreamResponse) }
    def mute_user(target_id, user_id)
      payload = { target_id: target_id, user_id: user_id }
      post('moderation/mute', data: payload)
    end

    # Unmutes a user.
    sig { params(target_id: String, user_id: String).returns(StreamChat::StreamResponse) }
    def unmute_user(target_id, user_id)
      payload = { target_id: target_id, user_id: user_id }
      post('moderation/unmute', data: payload)
    end

    # Marks all messages as read for a user.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def mark_all_read(user_id)
      payload = { user: { id: user_id } }
      post('channels/read', data: payload)
    end

    # Pins a message.
    #
    # Pinned messages allow users to highlight important messages, make announcements, or temporarily
    # promote content. Pinning a message is, by default, restricted to certain user roles,
    # but this is flexible. Each channel can have multiple pinned messages and these can be created
    # or updated with or without an expiration.
    sig { params(message_id: String, user_id: String, expiration: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def pin_message(message_id, user_id, expiration: nil)
      updates = {
        set: {
          pinned: true,
          pin_expires: expiration
        }
      }
      update_message_partial(message_id, updates, user_id: user_id)
    end

    # Unpins a message.
    sig { params(message_id: String, user_id: String).returns(StreamChat::StreamResponse) }
    def unpin_message(message_id, user_id)
      updates = {
        set: {
          pinned: false
        }
      }
      update_message_partial(message_id, updates, user_id: user_id)
    end

    #  commits a message.
    sig { params(message_id: String).returns(StreamChat::StreamResponse) }
    def commit_message(message_id)
      post("messages/#{message_id}/commit")
    end

    # Updates a message. Fully overwrites a message.
    # For partial update, use `update_message_partial` method.
    sig { params(message: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update_message(message)
      raise ArgumentError, 'message must have an id' unless message.key? 'id'

      post("messages/#{message['id']}", data: { message: message })
    end

    # Updates a message partially.
    # A partial update can be used to set and unset specific fields when
    # it is necessary to retain additional data fields on the object. AKA a patch style update.
    sig { params(message_id: String, updates: StringKeyHash, user_id: T.nilable(String), options: T.untyped).returns(StreamChat::StreamResponse) }
    def update_message_partial(message_id, updates, user_id: nil, **options)
      params = updates.merge(options)
      params['user'] = { id: user_id } if user_id
      put("messages/#{message_id}", data: params)
    end

    # Deletes a message.
    sig { params(message_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def delete_message(message_id, **options)
      delete("messages/#{message_id}", params: options)
    end

    # Queries banned users.
    #
    # Banned users can be retrieved in different ways:
    # 1) Using the dedicated query bans endpoint
    # 2) User Search: you can add the banned:true condition to your search. Please note that
    # this will only return users that were banned at the app-level and not the ones
    # that were banned only on channels.
    sig { params(filter_conditions: StringKeyHash, sort: T.nilable(T::Hash[String, Integer]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_banned_users(filter_conditions, sort: nil, **options)
      params = options.merge({
                               filter_conditions: filter_conditions,
                               sort: StreamChat.get_sort_fields(sort)
                             })
      get('query_banned_users', params: { payload: params.to_json })
    end

    # Allows you to search for users and see if they are online/offline.
    # You can filter and sort on the custom fields you've set for your user, the user id, and when the user was last active.
    sig { params(filter_conditions: StringKeyHash, sort: T.nilable(T::Hash[String, Integer]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_users(filter_conditions, sort: nil, **options)
      params = options.merge({
                               filter_conditions: filter_conditions,
                               sort: StreamChat.get_sort_fields(sort)
                             })
      get('users', params: { payload: params.to_json })
    end

    # Queries channels.
    #
    # You can query channels based on built-in fields as well as any custom field you add to channels.
    # Multiple filters can be combined using AND, OR logical operators, each filter can use its
    # comparison (equality, inequality, greater than, greater or equal, etc.).
    # You can find the complete list of supported operators in the query syntax section of the docs.
    sig { params(filter_conditions: StringKeyHash, sort: T.nilable(T::Hash[String, Integer]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_channels(filter_conditions, sort: nil, **options)
      data = { state: true, watch: false, presence: false }
      data = data.merge(options).merge({
                                         filter_conditions: filter_conditions,
                                         sort: StreamChat.get_sort_fields(sort)
                                       })
      post('channels', data: data)
    end

    # Creates a new channel type.
    sig { params(data: StringKeyHash).returns(StreamChat::StreamResponse) }
    def create_channel_type(data)
      data['commands'] = ['all'] unless data.key?('commands') || data['commands'].nil? || data['commands'].empty?
      post('channeltypes', data: data)
    end

    # Returns a channel types.
    sig { params(channel_type: String).returns(StreamChat::StreamResponse) }
    def get_channel_type(channel_type)
      get("channeltypes/#{channel_type}")
    end

    # Returns a list of channel types.
    sig { returns(StreamChat::StreamResponse) }
    def list_channel_types
      get('channeltypes')
    end

    # Updates a channel type.
    sig { params(channel_type: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def update_channel_type(channel_type, **options)
      put("channeltypes/#{channel_type}", data: options)
    end

    # Deletes a channel type.
    sig { params(channel_type: String).returns(StreamChat::StreamResponse) }
    def delete_channel_type(channel_type)
      delete("channeltypes/#{channel_type}")
    end

    # Creates a channel instance
    #
    # @param [string] channel_type the channel type
    # @param [string] channel_id the channel identifier
    # @param [StringKeyHash] data additional channel data
    #
    # @return [StreamChat::Channel]
    #
    sig { params(channel_type: String, channel_id: T.nilable(String), data: T.nilable(StringKeyHash)).returns(StreamChat::Channel) }
    def channel(channel_type, channel_id: nil, data: nil)
      StreamChat::Channel.new(self, channel_type, channel_id, data)
    end

    # Adds a device to a user.
    sig { params(device_id: String, push_provider: String, user_id: String, push_provider_name: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def add_device(device_id, push_provider, user_id, push_provider_name = nil)
      post('devices', data: {
             id: device_id,
             push_provider: push_provider,
             push_provider_name: push_provider_name,
             user_id: user_id
           })
    end

    # Delete a device.
    sig { params(device_id: String, user_id: String).returns(StreamChat::StreamResponse) }
    def delete_device(device_id, user_id)
      delete('devices', params: { id: device_id, user_id: user_id })
    end

    # Returns a list of devices.
    sig { params(user_id: String).returns(StreamChat::StreamResponse) }
    def get_devices(user_id)
      get('devices', params: { user_id: user_id })
    end

    # Get rate limit quotas and usage.
    # If no params are toggled, all limits for all endpoints are returned.
    sig { params(server_side: T::Boolean, android: T::Boolean, ios: T::Boolean, web: T::Boolean, endpoints: T::Array[String]).returns(StreamChat::StreamResponse) }
    def get_rate_limits(server_side: false, android: false, ios: false, web: false, endpoints: [])
      params = {}
      params['server_side'] = server_side if server_side
      params['android'] = android if android
      params['ios'] = ios if ios
      params['web'] = web if web
      params['endpoints'] = endpoints.join(',') unless endpoints.empty?

      get('rate_limits', params: params)
    end

    # Verify the signature added to a webhook event.
    sig { params(request_body: String, x_signature: String).returns(T::Boolean) }
    def verify_webhook(request_body, x_signature)
      signature = OpenSSL::HMAC.hexdigest('SHA256', @api_secret, request_body)
      signature == x_signature
    end

    # Allows you to send custom events to a connected user.
    sig { params(user_id: String, event: StringKeyHash).returns(StreamChat::StreamResponse) }
    def send_user_event(user_id, event)
      post("users/#{user_id}/event", data: event)
    end

    # Translates an existing message to another language. The source language
    # is inferred from the user language or detected automatically by analyzing its text.
    # If possible it is recommended to store the user language. See the documentation.
    sig { params(message_id: String, language: String).returns(StreamChat::StreamResponse) }
    def translate_message(message_id, language)
      post("messages/#{message_id}/translate", data: { language: language })
    end

    # Runs a message command action.
    sig { params(message_id: String, data: StringKeyHash).returns(StreamChat::StreamResponse) }
    def run_message_action(message_id, data)
      post("messages/#{message_id}/action", data: data)
    end

    # Creates a guest user.
    #
    # Guest sessions can be created client-side and do not require any server-side authentication.
    # Support and livestreams are common use cases for guests users because really
    # often you want a visitor to be able to use chat on your application without (or before)
    # they have a regular user account.
    sig { params(user: StringKeyHash).returns(StreamChat::StreamResponse) }
    def create_guest(user)
      post('guests', data: user)
    end

    # Returns all blocklists.
    #
    # A Block List is a list of words that you can use to moderate chat messages. Stream Chat
    # comes with a built-in Block List called profanity_en_2020_v1 which contains over a thousand
    # of the most common profane words.
    # You can manage your own block lists via the Stream dashboard or APIs to a manage
    # blocklists and configure your channel types to use them.
    sig { returns(StreamChat::StreamResponse) }
    def list_blocklists
      get('blocklists')
    end

    # Returns a blocklist.
    #
    # A Block List is a list of words that you can use to moderate chat messages. Stream Chat
    # comes with a built-in Block List called profanity_en_2020_v1 which contains over a thousand
    # of the most common profane words.
    # You can manage your own block lists via the Stream dashboard or APIs to a manage
    # blocklists and configure your channel types to use them.
    sig { params(name: String).returns(StreamChat::StreamResponse) }
    def get_blocklist(name)
      get("blocklists/#{name}")
    end

    # Creates a blocklist.
    #
    # A Block List is a list of words that you can use to moderate chat messages. Stream Chat
    # comes with a built-in Block List called profanity_en_2020_v1 which contains over a thousand
    # of the most common profane words.
    # You can manage your own block lists via the Stream dashboard or APIs to a manage
    # blocklists and configure your channel types to use them.
    sig { params(name: String, words: T::Array[String]).returns(StreamChat::StreamResponse) }
    def create_blocklist(name, words)
      post('blocklists', data: { name: name, words: words })
    end

    # Updates a blocklist.
    #
    # A Block List is a list of words that you can use to moderate chat messages. Stream Chat
    # comes with a built-in Block List called profanity_en_2020_v1 which contains over a thousand
    # of the most common profane words.
    # You can manage your own block lists via the Stream dashboard or APIs to a manage
    # blocklists and configure your channel types to use them.
    sig { params(name: String, words: T::Array[String]).returns(StreamChat::StreamResponse) }
    def update_blocklist(name, words)
      put("blocklists/#{name}", data: { words: words })
    end

    # Deletes a blocklist.
    #
    # A Block List is a list of words that you can use to moderate chat messages. Stream Chat
    # comes with a built-in Block List called profanity_en_2020_v1 which contains over a thousand
    # of the most common profane words.
    # You can manage your own block lists via the Stream dashboard or APIs to a manage
    # blocklists and configure your channel types to use them.
    sig { params(name: String).returns(StreamChat::StreamResponse) }
    def delete_blocklist(name)
      delete("blocklists/#{name}")
    end

    # Requests a channel export.
    #
    # Channel exports are created asynchronously, you can use the Task ID returned by
    # the APIs to keep track of the status and to download the final result when it is ready.
    # Use `get_task` to check the status of the export.
    sig { params(channels: StringKeyHash, options: T.untyped).returns(StreamChat::StreamResponse) }
    def export_channels(*channels, **options)
      post('export_channels', data: { channels: channels, **options })
    end

    # Returns the status of a channel export. It contains the URL to the JSON file.
    sig { params(task_id: String).returns(StreamChat::StreamResponse) }
    def get_export_channel_status(task_id)
      get("export_channels/#{task_id}")
    end

    # Requests a users export.
    #
    # User exports are created asynchronously, you can use the Task ID returned by
    # the APIs to keep track of the status and to download the final result when it is ready.
    # Use `get_task` to check the status of the export.
    sig { params(user_ids: T::Array[String]).returns(StreamChat::StreamResponse) }
    def export_users(user_ids)
      post('export/users', data: { user_ids: user_ids })
    end

    # Returns the status of a task.
    sig { params(task_id: String).returns(StreamChat::StreamResponse) }
    def get_task(task_id)
      get("tasks/#{task_id}")
    end

    # Delete users asynchronously. Use `get_task` to check the status of the task.
    sig { params(user_ids: T::Array[String], user: String, messages: T.nilable(String), conversations: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def delete_users(user_ids, user: SOFT_DELETE, messages: nil, conversations: nil)
      post('users/delete', data: { user_ids: user_ids, user: user, messages: messages, conversations: conversations })
    end

    # Deletes multiple channels. This is an asynchronous operation and the returned value is a task Id.
    # You can use `get_task` method to check the status of the task.
    sig { params(cids: T::Array[String], hard_delete: T::Boolean).returns(StreamChat::StreamResponse) }
    def delete_channels(cids, hard_delete: false)
      post('channels/delete', data: { cids: cids, hard_delete: hard_delete })
    end

    # Revoke tokens for an application issued since the given date.
    sig { params(before: T.any(DateTime, String)).returns(StreamChat::StreamResponse) }
    def revoke_tokens(before)
      before = T.cast(before, DateTime).rfc3339 if before.instance_of?(DateTime)
      update_app_settings({ 'revoke_tokens_issued_before' => before })
    end

    # Revoke tokens for a user issued since the given date.
    sig { params(user_id: String, before: T.any(DateTime, String)).returns(StreamChat::StreamResponse) }
    def revoke_user_token(user_id, before)
      revoke_users_token([user_id], before)
    end

    # Revoke tokens for users issued since.
    sig { params(user_ids: T::Array[String], before: T.any(DateTime, String)).returns(StreamChat::StreamResponse) }
    def revoke_users_token(user_ids, before)
      before = T.cast(before, DateTime).rfc3339 if before.instance_of?(DateTime)

      updates = []
      user_ids.map do |user_id|
        {
          'id' => user_id,
          'set' => {
            'revoke_tokens_issued_before' => before
          }
        }
      end
      update_users_partial(updates)
    end

    sig { params(relative_url: String, params: T.nilable(StringKeyHash), data: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def put(relative_url, params: nil, data: nil)
      make_http_request(:put, relative_url, params: params, data: data)
    end

    sig { params(relative_url: String, params: T.nilable(StringKeyHash), data: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def post(relative_url, params: nil, data: nil)
      make_http_request(:post, relative_url, params: params, data: data)
    end

    sig { params(relative_url: String, params: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def get(relative_url, params: nil)
      make_http_request(:get, relative_url, params: params)
    end

    sig { params(relative_url: String, params: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def delete(relative_url, params: nil)
      make_http_request(:delete, relative_url, params: params)
    end

    sig { params(relative_url: String, params: T.nilable(StringKeyHash), data: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def patch(relative_url, params: nil, data: nil)
      make_http_request(:patch, relative_url, params: params, data: data)
    end

    # Uploads a file.
    #
    # This functionality defaults to using the Stream CDN. If you would like, you can
    # easily change the logic to upload to your own CDN of choice.
    sig { params(relative_url: String, file_url: String, user: StringKeyHash, content_type: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def send_file(relative_url, file_url, user, content_type = nil)
      url = [@base_url, relative_url].join('/')

      body = { user: user.to_json }

      body[:file] = Faraday::UploadIO.new(file_url, content_type || 'application/octet-stream')

      response = @conn.post url do |req|
        req.headers['X-Stream-Client'] = get_user_agent
        req.headers['Authorization'] = @auth_token
        req.headers['stream-auth-type'] = 'jwt'
        req.params = get_default_params
        req.body = body
      end

      parse_response(response)
    end

    # Check push notification settings.
    sig { params(push_data: StringKeyHash).returns(StreamChat::StreamResponse) }
    def check_push(push_data)
      post('check_push', data: push_data)
    end

    # Check SQS Push settings
    #
    # When no parameters are given, the current SQS app settings are used.
    sig { params(sqs_key: T.nilable(String), sqs_secret: T.nilable(String), sqs_url: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def check_sqs(sqs_key = nil, sqs_secret = nil, sqs_url = nil)
      post('check_sqs', data: { sqs_key: sqs_key, sqs_secret: sqs_secret, sqs_url: sqs_url })
    end

    # Check SNS Push settings
    #
    # When no parameters are given, the current SNS app settings are used.
    sig { params(sns_key: T.nilable(String), sns_secret: T.nilable(String), sns_topic_arn: T.nilable(String)).returns(StreamChat::StreamResponse) }
    def check_sns(sns_key = nil, sns_secret = nil, sns_topic_arn = nil)
      post('check_sns', data: { sns_key: sns_key, sns_secret: sns_secret, sns_topic_arn: sns_topic_arn })
    end

    # Creates a new command.
    sig { params(command: StringKeyHash).returns(StreamChat::StreamResponse) }
    def create_command(command)
      post('commands', data: command)
    end

    # Queries draft messages for the current user.
    #
    # @param [String] user_id The ID of the user to query drafts for
    # @param [StringKeyHash] filter Optional filter conditions for the query
    # @param [Array] sort Optional sort parameters
    # @param [Hash] options Additional query options
    # @return [StreamChat::StreamResponse]
    sig { params(user_id: String, filter: T.nilable(StringKeyHash), sort: T.nilable(T::Array[StringKeyHash]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_drafts(user_id, filter: nil, sort: nil, **options)
      data = { user_id: user_id }
      data['filter'] = filter if filter
      data['sort'] = sort if sort
      data.merge!(options) if options
      post('drafts/query', data: data)
    end

    # Gets a comamnd.
    sig { params(name: String).returns(StreamChat::StreamResponse) }
    def get_command(name)
      get("commands/#{name}")
    end

    # Updates a command.
    sig { params(name: String, command: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update_command(name, command)
      put("commands/#{name}", data: command)
    end

    # Deletes a command.
    sig { params(name: String).returns(StreamChat::StreamResponse) }
    def delete_command(name)
      delete("commands/#{name}")
    end

    # Lists all commands.
    sig { returns(StreamChat::StreamResponse) }
    def list_commands
      get('commands')
    end

    # Lists all permissions.
    sig { returns(StreamChat::StreamResponse) }
    def list_permissions
      get('permissions')
    end

    # Gets a permission.
    sig { params(id: String).returns(StreamChat::StreamResponse) }
    def get_permission(id)
      get("permissions/#{id}")
    end

    # Creates a new permission.
    sig { params(permission: StringKeyHash).returns(StreamChat::StreamResponse) }
    def create_permission(permission)
      post('permissions', data: permission)
    end

    # Updates a permission.
    sig { params(id: String, permission: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update_permission(id, permission)
      put("permissions/#{id}", data: permission)
    end

    # Deletes a permission by id.
    sig { params(id: String).returns(StreamChat::StreamResponse) }
    def delete_permission(id)
      delete("permissions/#{id}")
    end

    # Create a new role.
    sig { params(name: String).returns(StreamChat::StreamResponse) }
    def create_role(name)
      post('roles', data: { name: name })
    end

    # Delete a role by name.
    sig { params(name: String).returns(StreamChat::StreamResponse) }
    def delete_role(name)
      delete("roles/#{name}")
    end

    # List all roles.
    sig { returns(StreamChat::StreamResponse) }
    def list_roles
      get('roles')
    end

    # Create or update a push provider.
    sig { params(push_provider: StringKeyHash).returns(StreamChat::StreamResponse) }
    def upsert_push_provider(push_provider)
      post('push_providers', data: { push_provider: push_provider })
    end

    # Delete a push provider by type and name.
    sig { params(type: String, name: String).returns(StreamChat::StreamResponse) }
    def delete_push_provider(type, name)
      delete("push_providers/#{type}/#{name}")
    end

    # Lists all push providers.
    sig { returns(StreamChat::StreamResponse) }
    def list_push_providers
      get('push_providers')
    end

    # Creates a signed URL for imports.
    # @example
    #   url_resp = client.create_import_url('myfile.json')
    #   Faraday.put(url_resp['upload_url'], File.read('myfile.json'), 'Content-Type' => 'application/json')
    #   client.create_import(url_resp['path'], 'upsert')
    sig { params(filename: String).returns(StreamChat::StreamResponse) }
    def create_import_url(filename)
      post('import_urls', data: { filename: filename })
    end

    # Creates a new import.
    # @example
    #   url_resp = client.create_import_url('myfile.json')
    #   Faraday.put(url_resp['upload_url'], File.read('myfile.json'), 'Content-Type' => 'application/json')
    #   client.create_import(url_resp['path'], 'upsert')
    sig { params(path: String, mode: String).returns(StreamChat::StreamResponse) }
    def create_import(path, mode)
      post('imports', data: { path: path, mode: mode })
    end

    # Returns an import by id.
    sig { params(id: String).returns(StreamChat::StreamResponse) }
    def get_import(id)
      get("imports/#{id}")
    end

    # Lists imports. Options dictionary can contain 'offset' and 'limit' keys for pagination.
    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def list_imports(options)
      get('imports', params: options)
    end

    private

    sig { returns(T::Hash[String, String]) }
    def get_default_params
      { api_key: @api_key }
    end

    sig { returns(String) }
    def get_user_agent
      "stream-ruby-client-#{StreamChat::VERSION}"
    end

    sig { returns(T::Hash[String, String]) }
    def get_default_headers
      {
        'Content-Type': 'application/json',
        'X-Stream-Client': get_user_agent
      }
    end

    sig { params(response: Faraday::Response).returns(StreamChat::StreamResponse) }
    def parse_response(response)
      begin
        parsed_result = JSON.parse(response.body)
      rescue JSON::ParserError
        raise StreamAPIException, response
      end
      raise StreamAPIException, response if response.status >= 399

      StreamResponse.new(parsed_result, response)
    end

    sig { params(method: Symbol, relative_url: String, params: T.nilable(StringKeyHash), data: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def make_http_request(method, relative_url, params: nil, data: nil)
      headers = get_default_headers
      headers['Authorization'] = @auth_token
      headers['stream-auth-type'] = 'jwt'
      params = {} if params.nil?
      params = (get_default_params.merge(params).sort_by { |k, _v| k.to_s }).to_h
      url = "#{relative_url}?#{URI.encode_www_form(params)}"

      body = data.to_json if %w[patch post put].include? method.to_s

      response = @conn.run_request(
        method,
        url,
        body,
        headers
      )
      parse_response(response)
    end
  end
end
