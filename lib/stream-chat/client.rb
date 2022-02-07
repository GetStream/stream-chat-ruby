# frozen_string_literal: true

# lib/client.rb
require 'open-uri'
require 'faraday'
require 'faraday/multipart'
require 'faraday/net_http_persistent'
require 'jwt'
require 'time'
require 'stream-chat/channel'
require 'stream-chat/errors'
require 'stream-chat/stream_response'
require 'stream-chat/version'
require 'stream-chat/util'

module StreamChat
  DEFAULT_BLOCKLIST = 'profanity_en_2020_v1'
  SOFT_DELETE = 'soft'
  HARD_DELETE = 'hard'

  class Client
    DEFAULT_BASE_URL = 'https://chat.stream-io-api.com'
    DEFAULT_TIMEOUT = 6.0

    attr_reader :api_key
    attr_reader :api_secret
    attr_reader :conn
    attr_reader :options

    # initializes a Stream Chat API Client
    #
    # @param [string] api_key your application api_key
    # @param [string] api_secret your application secret
    # @param [float] timeout the timeout for the http requests
    # @param [hash] options extra options such as base_url
    #
    # @example initialized the client with a timeout setting
    #   StreamChat::Client.new('my_key', 'my_secret', 3.0)
    #
    def initialize(api_key, api_secret, timeout = nil, **options)
      raise ArgumentError, 'api_key and api_secret are required' if api_key.to_s.empty? || api_secret.to_s.empty?

      @api_key = api_key
      @api_secret = api_secret
      @timeout = timeout || DEFAULT_TIMEOUT
      @options = options
      @auth_token = JWT.encode({ server: true }, @api_secret, 'HS256')
      @base_url = options[:base_url] || DEFAULT_BASE_URL
      @conn = Faraday.new(url: @base_url) do |faraday|
        faraday.options[:open_timeout] = @timeout
        faraday.options[:timeout] = @timeout
        faraday.request :multipart
        faraday.adapter :net_http_persistent, pool_size: 5 do |http|
          # AWS load balancer idle timeout is 60 secs, so let's make it 59
          http.idle_timeout = 59
        end
      end
    end

    # initializes a Stream Chat API Client from STREAM_KEY and STREAM_SECRET
    # environmental variables. STREAM_CHAT_TIMEOUT and STREAM_CHAT_URL
    # variables are optional.
    # @param [hash] options extra options
    def self.from_env(**options)
      Client.new(ENV['STREAM_KEY'],
                 ENV['STREAM_SECRET'],
                 ENV['STREAM_CHAT_TIMEOUT'],
                 **{ base_url: ENV['STREAM_CHAT_URL'] }.merge(options))
    end

    # Sets the underlying Faraday http client.
    #
    # @param [client] an instance of Faraday::Connection
    def set_http_client(client)
      @conn = client
    end

    def create_token(user_id, exp = nil, iat = nil)
      payload = { user_id: user_id }
      payload['exp'] = exp unless exp.nil?
      payload['iat'] = iat unless iat.nil?
      JWT.encode(payload, @api_secret, 'HS256')
    end

    def update_app_settings(**settings)
      patch('app', **settings)
    end

    def get_app_settings
      get('app')
    end

    def flag_message(id, **options)
      payload = { target_message_id: id }.merge(options)
      post('moderation/flag', data: payload)
    end

    def unflag_message(id, **options)
      payload = { target_message_id: id }.merge(options)
      post('moderation/unflag', data: payload)
    end

    def query_message_flags(filter_conditions, **options)
      params = options.merge({
                               filter_conditions: filter_conditions
                             })
      get('moderation/flags/message', params: { payload: params.to_json })
    end

    def flag_user(id, **options)
      payload = { target_user_id: id }.merge(options)
      post('moderation/flag', data: payload)
    end

    def unflag_user(id, **options)
      payload = { target_user_id: id }.merge(options)
      post('moderation/unflag', data: payload)
    end

    def get_message(id)
      get("messages/#{id}")
    end

    def search(filter_conditions, query, sort: nil, **options)
      offset = options[:offset]
      next_value = options[:next]
      raise ArgumentError, 'cannot use offset with next or sort parameters' if offset&.positive? && (next_value || (!sort.nil? && !sort.empty?))

      to_merge = {
        filter_conditions: filter_conditions,
        sort: get_sort_fields(sort)
      }
      if query.is_a? String
        to_merge[:query] = query
      else
        to_merge[:message_filter_conditions] = query
      end
      get('search', params: { payload: options.merge(to_merge).to_json })
    end

    def update_users(users)
      payload = {}
      users.each do |user|
        id = user[:id] || user['id']
        raise ArgumentError, 'user must have an id' unless id

        payload[id] = user
      end
      post('users', data: { users: payload })
    end

    def update_user(user)
      update_users([user])
    end

    def update_users_partial(updates)
      patch('users', data: { users: updates })
    end

    def update_user_partial(update)
      update_users_partial([update])
    end

    def delete_user(user_id, **options)
      delete("users/#{user_id}", params: options)
    end

    def deactivate_user(user_id, **options)
      post("users/#{user_id}/deactivate", **options)
    end

    def reactivate_user(user_id, **options)
      post("users/#{user_id}/reactivate", **options)
    end

    def export_user(user_id, **options)
      get("users/#{user_id}/export", params: options)
    end

    def ban_user(target_id, **options)
      payload = { target_user_id: target_id }.merge(options)
      post('moderation/ban', data: payload)
    end

    def unban_user(target_id, **options)
      params = { target_user_id: target_id }.merge(options)
      delete('moderation/ban', params: params)
    end

    def shadow_ban(target_id, **options)
      payload = { target_user_id: target_id, shadow: true }.merge(options)
      post('moderation/ban', data: payload)
    end

    def remove_shadow_ban(target_id, **options)
      params = { target_user_id: target_id, shadow: true }.merge(options)
      delete('moderation/ban', params: params)
    end

    def mute_user(target_id, user_id)
      payload = { target_id: target_id, user_id: user_id }
      post('moderation/mute', data: payload)
    end

    def unmute_user(target_id, user_id)
      payload = { target_id: target_id, user_id: user_id }
      post('moderation/unmute', data: payload)
    end

    def mark_all_read(user_id)
      payload = { user: { id: user_id } }
      post('channels/read', data: payload)
    end

    def pin_message(message_id, user_id, expiration: nil)
      updates = {
        set: {
          pinned: true,
          pin_expires: expiration
        }
      }
      update_message_partial(message_id, updates, user_id: user_id)
    end

    def unpin_message(message_id, user_id)
      updates = {
        set: {
          pinned: false
        }
      }
      update_message_partial(message_id, updates, user_id: user_id)
    end

    def update_message(message)
      raise ArgumentError 'message must have an id' unless message.key? 'id'

      post("messages/#{message['id']}", data: { message: message })
    end

    def update_message_partial(message_id, updates, user_id: nil, **options)
      params = updates.merge(options)
      params['user'] = { id: user_id } if user_id
      put("messages/#{message_id}", data: params)
    end

    def delete_message(message_id, **options)
      delete("messages/#{message_id}", params: options)
    end

    def query_banned_users(filter_conditions, sort: nil, **options)
      params = options.merge({
                               filter_conditions: filter_conditions,
                               sort: get_sort_fields(sort)
                             })
      get('query_banned_users', params: { payload: params.to_json })
    end

    def query_users(filter_conditions, sort: nil, **options)
      params = options.merge({
                               filter_conditions: filter_conditions,
                               sort: get_sort_fields(sort)
                             })
      get('users', params: { payload: params.to_json })
    end

    def query_channels(filter_conditions, sort: nil, **options)
      data = { state: true, watch: false, presence: false }
      data = data.merge(options).merge({
                                         filter_conditions: filter_conditions,
                                         sort: get_sort_fields(sort)
                                       })
      post('channels', data: data)
    end

    def create_channel_type(data)
      data['commands'] = ['all'] unless data.key?('commands') || data['commands'].nil? || data['commands'].empty?
      post('channeltypes', data: data)
    end

    def get_channel_type(channel_type)
      get("channeltypes/#{channel_type}")
    end

    def list_channel_types
      get('channeltypes')
    end

    def update_channel_type(channel_type, **options)
      put("channeltypes/#{channel_type}", data: options)
    end

    def delete_channel_type(channel_type)
      delete("channeltypes/#{channel_type}")
    end

    # Creates a channel instance
    #
    # @param [string] channel_type the channel type
    # @param [string] channel_id the channel identifier
    # @param [hash] data additional channel data
    #
    # @return [StreamChat::Channel]
    #
    def channel(channel_type, channel_id: nil, data: nil)
      StreamChat::Channel.new(self, channel_type, channel_id, data)
    end

    def add_device(device_id, push_provider, user_id)
      post('devices', data: {
             id: device_id,
             push_provider: push_provider,
             user_id: user_id
           })
    end

    def delete_device(device_id, user_id)
      delete('devices', params: { id: device_id, user_id: user_id })
    end

    def get_devices(user_id)
      get('devices', params: { user_id: user_id })
    end

    def get_rate_limits(server_side: false, android: false, ios: false, web: false, endpoints: [])
      params = {}
      params['server_side'] = server_side if server_side
      params['android'] = android if android
      params['ios'] = ios if ios
      params['web'] = web if web
      params['endpoints'] = endpoints.join(',') unless endpoints.empty?

      get('rate_limits', params: params)
    end

    def verify_webhook(request_body, x_signature)
      signature = OpenSSL::HMAC.hexdigest('SHA256', @api_secret, request_body)
      signature == x_signature
    end

    def send_user_event(user_id, event)
      post("users/#{user_id}/event", data: event)
    end

    def translate_message(message_id, language)
      post("messages/#{message_id}/translate", data: { language: language })
    end

    def run_message_action(message_id, data)
      post("messages/#{message_id}/action", data: data)
    end

    def create_guest(user)
      post('guests', data: user)
    end

    def list_blocklists
      get('blocklists')
    end

    def get_blocklist(name)
      get("blocklists/#{name}")
    end

    def create_blocklist(name, words)
      post('blocklists', data: { name: name, words: words })
    end

    def update_blocklist(name, words)
      put("blocklists/#{name}", data: { words: words })
    end

    def delete_blocklist(name)
      delete("blocklists/#{name}")
    end

    def export_channels(*channels, **options)
      post('export_channels', data: { channels: channels, **options })
    end

    def get_export_channel_status(task_id)
      get("export_channels/#{task_id}")
    end

    def get_task(task_id)
      get("tasks/#{task_id}")
    end

    def delete_users(user_ids, user: SOFT_DELETE, messages: nil, conversations: nil)
      post('users/delete', data: { user_ids: user_ids, user: user, messages: messages, conversations: conversations })
    end

    def delete_channels(cids, hard_delete: false)
      post('channels/delete', data: { cids: cids, hard_delete: hard_delete })
    end

    def revoke_tokens(before)
      before = before.rfc3339 if before.instance_of?(DateTime)
      update_app_settings({ 'revoke_tokens_issued_before' => before })
    end

    def revoke_user_token(user_id, before)
      revoke_users_token([user_id], before)
    end

    def revoke_users_token(user_ids, before)
      before = before.rfc3339 if before.instance_of?(DateTime)

      updates = []
      user_ids.each do |user_id|
        updates.push({
                       'id' => user_id,
                       'set' => {
                         'revoke_tokens_issued_before' => before
                       }
                     })
      end
      update_users_partial(updates)
    end

    def put(relative_url, params: nil, data: nil)
      make_http_request(:put, relative_url, params: params, data: data)
    end

    def post(relative_url, params: nil, data: nil)
      make_http_request(:post, relative_url, params: params, data: data)
    end

    def get(relative_url, params: nil)
      make_http_request(:get, relative_url, params: params)
    end

    def delete(relative_url, params: nil)
      make_http_request(:delete, relative_url, params: params)
    end

    def patch(relative_url, params: nil, data: nil)
      make_http_request(:patch, relative_url, params: params, data: data)
    end

    def send_file(relative_url, file_url, user, content_type = 'application/octet-stream')
      url = [@base_url, relative_url].join('/')

      body = { user: user.to_json }

      body[:file] = Faraday::UploadIO.new(file_url, content_type)

      response = @conn.post url do |req|
        req.headers['X-Stream-Client'] = get_user_agent
        req.headers['Authorization'] = @auth_token
        req.headers['stream-auth-type'] = 'jwt'
        req.params = get_default_params
        req.body = body
      end

      parse_response(response)
    end

    def check_push(push_data)
      post('check_push', data: push_data)
    end

    def check_sqs(sqs_key = nil, sqs_secret = nil, sqs_url = nil)
      post('check_sqs', data: { sqs_key: sqs_key, sqs_secret: sqs_secret, sqs_url: sqs_url })
    end

    def create_command(command)
      post('commands', data: command)
    end

    def get_command(name)
      get("commands/#{name}")
    end

    def update_command(name, command)
      put("commands/#{name}", data: command)
    end

    def delete_command(name)
      delete("commands/#{name}")
    end

    def list_commands
      get('commands')
    end

    def list_permissions
      get('permissions')
    end

    def get_permission(id)
      get("permissions/#{id}")
    end

    def create_permission(permission)
      post('permissions', data: permission)
    end

    def update_permission(id, permission)
      put("permissions/#{id}", data: permission)
    end

    def delete_permission(id)
      delete("permissions/#{id}")
    end

    def create_role(name)
      post('roles', data: { name: name })
    end

    def delete_role(name)
      delete("roles/#{name}")
    end

    def list_roles
      get('roles')
    end

    private

    def get_default_params
      { api_key: @api_key }
    end

    def get_user_agent
      "stream-ruby-client-#{StreamChat::VERSION}"
    end

    def get_default_headers
      {
        'Content-Type': 'application/json',
        'X-Stream-Client': get_user_agent
      }
    end

    def parse_response(response)
      begin
        parsed_result = JSON.parse(response.body)
      rescue JSON::ParserError
        raise StreamAPIException, response
      end
      raise StreamAPIException, response if response.status >= 399

      StreamResponse.new(parsed_result, response)
    end

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
