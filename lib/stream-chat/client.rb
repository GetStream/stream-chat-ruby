# frozen_string_literal: true

# lib/client.rb
require 'open-uri'
require 'faraday'
require 'jwt'
require 'stream-chat/channel'
require 'stream-chat/errors'
require 'stream-chat/version'
require 'stream-chat/util'

module StreamChat
  DEFAULT_BLOCKLIST = 'profanity_en_2020_v1'

  class Client
    BASE_URL = 'https://chat-us-east-1.stream-io-api.com'

    attr_reader :api_key
    attr_reader :api_secret
    attr_reader :conn
    attr_reader :options

    # initializes a Stream Chat API Client
    #
    # @param [string] api_key your application api_key
    # @param [string] api_secret your application secret
    # @param [string]
    # @param [hash] options extra options
    #
    # @example initialized the client with a timeout setting
    #   StreamChat::Client.new('my_key', 'my_secret', 3.0)
    #
    def initialize(api_key = '', api_secret = '', timeout = 6.0, **options)
      @api_key = api_key
      @api_secret = api_secret
      @timeout = timeout
      @options = options
      @auth_token = JWT.encode({ server: true }, @api_secret, 'HS256')
      @base_url = options[:base_url] || BASE_URL
      @conn = Faraday.new(url: @base_url) do |faraday|
        faraday.options[:open_timeout] = @timeout
        faraday.options[:timeout] = @timeout
        faraday.request :multipart
        faraday.adapter :net_http
      end
    end

    def create_token(user_id, exp = nil)
      payload = { user_id: user_id }
      payload['exp'] = exp unless exp.nil?
      JWT.encode(payload, @api_secret, 'HS256')
    end

    def update_app_settings(**settings)
      patch('app', **settings)
    end

    def get_app_settings
      get('app')
    end

    def flag_message(id, **options)
      payload = { 'target_message_id': id }.merge(options)
      post('moderation/flag', data: payload)
    end

    def unflag_message(id, **options)
      payload = { 'target_message_id': id }.merge(options)
      post('moderation/unflag', data: payload)
    end

    def flag_user(id, **options)
      payload = { 'target_user_id': id }.merge(options)
      post('moderation/flag', data: payload)
    end

    def unflag_user(id, **options)
      payload = { 'target_user_id': id }.merge(options)
      post('moderation/unflag', data: payload)
    end

    def get_message(id)
      get("messages/#{id}")
    end

    def search(filter_conditions, query, **options)
      params = options.merge({
                               "filter_conditions": filter_conditions,
                               "query": query
                             })

      get('search', params: { "payload": params.to_json })
    end

    def update_users(users)
      payload = {}
      users.each do |user|
        id = user[:id] || user['id']
        raise ArgumentError, 'user must have an id' unless id

        payload[id] = user
      end
      post('users', data: { 'users': payload })
    end

    def update_user(user)
      update_users([user])
    end

    def update_users_partial(updates)
      patch('users', data: { 'users': updates })
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
      payload = { 'target_user_id': target_id }.merge(options)
      post('moderation/ban', data: payload)
    end

    def unban_user(target_id, **options)
      params = { 'target_user_id': target_id }.merge(options)
      delete('moderation/ban', params: params)
    end

    def mute_user(target_id, user_id)
      payload = { 'target_id': target_id, 'user_id': user_id }
      post('moderation/mute', data: payload)
    end

    def unmute_user(target_id, user_id)
      payload = { 'target_id': target_id, 'user_id': user_id }
      post('moderation/unmute', data: payload)
    end

    def mark_all_read(user_id)
      payload = { 'user': { 'id': user_id } }
      post('channels/read', data: payload)
    end

    def update_message(message)
      raise ArgumentError 'message must have an id' unless message.key? 'id'

      post("messages/#{message['id']}", data: { 'message': message })
    end

    def delete_message(message_id)
      delete("messages/#{message_id}")
    end

    def query_users(filter_conditions, sort: nil, **options)
      params = options.merge({
                               "filter_conditions": filter_conditions,
                               "sort": get_sort_fields(sort)
                             })
      get('users', params: { "payload": params.to_json })
    end

    def query_channels(filter_conditions, sort: nil, **options)
      params = { "state": true, "watch": false, "presence": false }
      params = params.merge(options).merge({
                                             "filter_conditions": filter_conditions,
                                             "sort": get_sort_fields(sort)
                                           })
      get('channels', params: { "payload": params.to_json })
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
             "id": device_id,
             "push_provider": push_provider,
             "user_id": user_id
           })
    end

    def delete_device(device_id, user_id)
      delete('devices', params: { "id": device_id, "user_id": user_id })
    end

    def get_devices(user_id)
      get('devices', params: { "user_id": user_id })
    end

    def verify_webhook(request_body, x_signature)
      signature = OpenSSL::HMAC.hexdigest('SHA256', @api_secret, request_body)
      signature == x_signature
    end

    def list_blocklists
      get('blocklists')
    end

    def get_blocklist(name)
      get("blocklists/#{name}")
    end

    def create_blocklist(name, words)
      post('blocklists', data: { "name": name, "words": words })
    end

    def update_blocklist(name, words)
      put("blocklists/#{name}", data: { "words": words })
    end

    def delete_blocklist(name)
      delete("blocklists/#{name}")
    end

    def export_channels(*channels)
      post('export_channels', data: { "channels": channels })
    end

    def get_export_channel_status(task_id)
      get("export_channels/#{task_id}")
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

      file = open(file_url)
      body = { user: user.to_json }

      body[:file] = Faraday::UploadIO.new(file, content_type)

      response = @conn.post url do |req|
        req.headers['X-Stream-Client'] = get_user_agent
        req.headers['Authorization'] = @auth_token
        req.headers['stream-auth-type'] = 'jwt'
        req.params = get_default_params
        req.body = body
      end

      parse_response(response)
    end

    def check_sqs(sqs_key = nil, sqs_secret = nil, sqs_url = nil)
      post('check_sqs', data: { "sqs_key": sqs_key, "sqs_secret": sqs_secret, "sqs_url": sqs_url })
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
        "Content-Type": 'application/json',
        "X-Stream-Client": get_user_agent
      }
    end

    def parse_response(response)
      begin
        parsed_result = JSON.parse(response.body)
      rescue JSON::ParserError
        raise StreamAPIException, response
      end
      raise StreamAPIException, response if response.status >= 399

      parsed_result
    end

    def make_http_request(method, relative_url, params: nil, data: nil)
      headers = get_default_headers
      headers['Authorization'] = @auth_token
      headers['stream-auth-type'] = 'jwt'
      url = [@base_url, relative_url].join('/')
      params = params.nil? ? {} : params
      params = Hash[get_default_params.merge(params).sort_by { |k, _v| k.to_s }]
      url = "#{url}?#{URI.encode_www_form(params)}"

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
