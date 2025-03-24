# typed: strict
# frozen_string_literal: true

require 'stream-chat/client'
require 'stream-chat/errors'
require 'stream-chat/util'
require 'stream-chat/types'

module StreamChat
  # Moderation class provides all the endpoints related to moderation v2
  class Moderation
    extend T::Sig

    MODERATION_ENTITY_TYPES = T.let(
      {
        user: 'stream:user',
        message: 'stream:chat:v1:message'
      }.freeze,
      T::Hash[Symbol, String]
    )

    sig { params(client: Client).void }
    def initialize(client)
      @client = client
    end

    # Flags a user with a reason
    #
    # @param [string] flagged_user_id User ID to be flagged
    # @param [string] reason Reason for flagging the user
    # @param [Hash] options Additional options for flagging the user
    # @option options [String] :user_id User ID of the user who is flagging the target user
    # @option options [Hash] :custom Additional data to be stored with the flag
    sig { params(flagged_user_id: String, reason: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def flag_user(flagged_user_id, reason, **options)
      flag(T.must(MODERATION_ENTITY_TYPES[:user]), flagged_user_id, reason, **options)
    end

    # Flags a message with a reason
    #
    # @param [string] message_id Message ID to be flagged
    # @param [string] reason Reason for flagging the message
    # @param [Hash] options Additional options for flagging the message
    # @option options [String] :user_id User ID of the user who is flagging the target message
    # @option options [Hash] :custom Additional data to be stored with the flag
    sig { params(message_id: String, reason: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def flag_message(message_id, reason, **options)
      flag(T.must(MODERATION_ENTITY_TYPES[:message]), message_id, reason, **options)
    end

    # Flags an entity with a reason
    #
    # @param [string] entity_type Entity type to be flagged
    # @param [string] entity_id Entity ID to be flagged
    # @param [string] reason Reason for flagging the entity
    # @param [string] entity_creator_id User ID of the entity creator (optional)
    # @param [Hash] options Additional options for flagging the entity
    # @option options [String] :user_id User ID of the user who is flagging the target entity
    # @option options [Hash] :moderation_payload Content to be flagged
    # @option options [Hash] :custom Additional data to be stored with the flag
    sig { params(entity_type: String, entity_id: String, reason: String, entity_creator_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def flag(entity_type, entity_id, reason, entity_creator_id: '', **options)
      @client.post('api/v2/moderation/flag', data: {
                     entity_type: entity_type,
                     entity_id: entity_id,
                     entity_creator_id: entity_creator_id,
                     reason: reason,
                     **options
                   })
    end

    # Mutes a user
    #
    # @param [string] target_id User ID to be muted
    # @param [Hash] options Additional options for muting the user
    # @option options [String] :user_id User ID of the user who is muting the target user
    # @option options [Integer] :timeout Timeout for the mute in minutes
    sig { params(target_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def mute_user(target_id, **options)
      @client.post('api/v2/moderation/mute', data: {
                     target_ids: [target_id],
                     **options
                   })
    end

    # Unmutes a user
    #
    # @param [string] target_id User ID to be unmuted
    # @param [Hash] options Additional options for unmuting the user
    # @option options [String] :user_id User ID of the user who is unmuting the target user
    sig { params(target_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def unmute_user(target_id, **options)
      @client.post('api/v2/moderation/unmute', data: {
                     target_ids: [target_id],
                     **options
                   })
    end

    # Gets moderation report for a user
    #
    # @param [string] user_id User ID for which moderation report is to be fetched
    # @param [Hash] options Additional options for fetching the moderation report
    # @option options [Boolean] :create_user_if_not_exists Create user if not exists
    # @option options [Boolean] :include_user_blocks Include user blocks
    # @option options [Boolean] :include_user_mutes Include user mutes
    sig { params(user_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def get_user_moderation_report(user_id, **options)
      @client.get('api/v2/moderation/user_report', params: {
                    user_id: user_id,
                    **options
                  })
    end

    # Queries review queue
    #
    # @param [Hash] filter_conditions Filter conditions for querying review queue
    # @param [Array] sort Sort conditions for querying review queue
    # @param [Hash] options Pagination options for querying review queue
    sig { params(filter_conditions: T.untyped, sort: T.untyped, options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_review_queue(filter_conditions = {}, sort = [], **options)
      @client.post('api/v2/moderation/review_queue', data: {
                     filter: filter_conditions,
                     sort: StreamChat.get_sort_fields(sort),
                     **options
                   })
    end

    # Upserts moderation config
    #
    # @param [Hash] config Moderation config to be upserted
    sig { params(config: T.untyped).returns(StreamChat::StreamResponse) }
    def upsert_config(config)
      @client.post('api/v2/moderation/config', data: config)
    end

    # Gets moderation config
    #
    # @param [string] key Key for which moderation config is to be fetched
    # @param [Hash] data Additional data
    # @option data [String] :team Team name
    sig { params(key: String, data: T.untyped).returns(StreamChat::StreamResponse) }
    def get_config(key, data = {})
      @client.get("api/v2/moderation/config/#{key}", params: data)
    end

    # Deletes moderation config
    #
    # @param [string] key Key for which moderation config is to be deleted
    # @param [Hash] data Additional data
    # @option data [String] :team Team name
    sig { params(key: String, data: T.untyped).returns(StreamChat::StreamResponse) }
    def delete_config(key, data = {})
      @client.delete("api/v2/moderation/config/#{key}", params: data)
    end

    # Queries moderation configs
    #
    # @param [Hash] filter_conditions Filter conditions for querying moderation configs
    # @param [Array] sort Sort conditions for querying moderation configs
    # @param [Hash] options Additional options for querying moderation configs
    sig { params(filter_conditions: T.untyped, sort: T.untyped, options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_configs(filter_conditions, sort, **options)
      @client.post('api/v2/moderation/configs', data: {
                     filter: filter_conditions,
                     sort: sort,
                     **options
                   })
    end

    # Submits a moderation action
    #
    # @param [string] action_type Type of action to submit
    # @param [string] item_id ID of the item to submit action for
    # @param [Hash] options Additional options for submitting the action
    sig { params(action_type: String, item_id: String, options: T.untyped).returns(StreamChat::StreamResponse) }
    def submit_action(action_type, item_id, **options)
      @client.post('api/v2/moderation/submit_action', data: {
                     action_type: action_type,
                     item_id: item_id,
                     **options
                   })
    end

    # rubocop:disable Metrics/ParameterLists
    # Checks content for moderation
    #
    # @param [string] entity_type Type of entity to be checked E.g., stream:user, stream:chat:v1:message, or any custom string
    # @param [string] entity_id ID of the entity to be checked. This is mainly for tracking purposes
    # @param [string] entity_creator_id ID of the entity creator
    # @param [Hash] moderation_payload Content to be checked for moderation
    # @option moderation_payload [Array<String>] :texts Array of texts to be checked for moderation
    # @option moderation_payload [Array<String>] :images Array of images to be checked for moderation
    # @option moderation_payload [Array<String>] :videos Array of videos to be checked for moderation
    # @option moderation_payload [Hash] :custom Additional custom data
    # @param [string] config_key Key of the moderation config to use
    # @param [Hash] options Additional options
    # @option options [Boolean] :force_sync Force synchronous check
    sig do
      params(
        entity_type: String,
        entity_id: String,
        moderation_payload: T::Hash[Symbol, T.any(T::Array[String], T::Hash[String, T.untyped])],
        config_key: String,
        entity_creator_id: String,
        options: T::Hash[Symbol, T::Boolean]
      ).returns(StreamChat::StreamResponse)
    end
    def check(entity_type, entity_id, moderation_payload, config_key, entity_creator_id: '', options: {})
      @client.post('api/v2/moderation/check', data: {
                     entity_type: entity_type,
                     entity_id: entity_id,
                     entity_creator_id: entity_creator_id,
                     moderation_payload: moderation_payload,
                     config_key: config_key,
                     options: options
                   })
    end
    # rubocop:enable Metrics/ParameterLists
    # Adds custom flags to an entity
    #
    # @param [string] entity_type Type of entity to be checked
    # @param [string] entity_id ID of the entity to be checked
    # @param [string] entity_creator_id ID of the entity creator
    # @param [Hash] moderation_payload Content to be checked for moderation
    # @param [Array] flags Array of custom flags to add
    sig { params(entity_type: String, entity_id: String, moderation_payload: T.untyped, flags: T::Array[T.untyped], entity_creator_id: String).returns(StreamChat::StreamResponse) }
    def add_custom_flags(entity_type, entity_id, moderation_payload, flags, entity_creator_id: '')
      @client.post('api/v2/moderation/custom_check', data: {
                     entity_type: entity_type,
                     entity_id: entity_id,
                     entity_creator_id: entity_creator_id,
                     moderation_payload: moderation_payload,
                     flags: flags
                   })
    end

    # Adds custom flags to a message
    #
    # @param [string] message_id Message ID to be flagged
    # @param [Array] flags Array of custom flags to add
    sig { params(message_id: String, flags: T::Array[T.untyped]).returns(StreamChat::StreamResponse) }
    def add_custom_message_flags(message_id, flags)
      add_custom_flags(T.must(MODERATION_ENTITY_TYPES[:message]), message_id, {}, flags)
    end
  end
end
