# typed: strict
# frozen_string_literal: true

require 'stream-chat/client'
require 'stream-chat/stream_response'
require 'stream-chat/types'

module StreamChat
  class ChannelBatchUpdater
    extend T::Sig

    sig { params(client: StreamChat::Client).void }
    def initialize(client)
      @client = client
    end

    # Member operations

    # addMembers - Add members to channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param members [T.any(T::Array[String], T::Array[StringKeyHash])] Members to add
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, members: T.any(T::Array[String], T::Array[StringKeyHash])).returns(StreamChat::StreamResponse) }
    def add_members(filter, members)
      @client.update_channels_batch(
        {
          operation: 'addMembers',
          filter: filter,
          members: members
        }
      )
    end

    # removeMembers - Remove members from channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param members [T::Array[String]] Member IDs to remove
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, members: T::Array[String]).returns(StreamChat::StreamResponse) }
    def remove_members(filter, members)
      @client.update_channels_batch(
        {
          operation: 'removeMembers',
          filter: filter,
          members: members
        }
      )
    end

    # inviteMembers - Invite members to channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param members [T.any(T::Array[String], T::Array[StringKeyHash])] Members to invite
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, members: T.any(T::Array[String], T::Array[StringKeyHash])).returns(StreamChat::StreamResponse) }
    def invite_members(filter, members)
      @client.update_channels_batch(
        {
          operation: 'invites',
          filter: filter,
          members: members
        }
      )
    end

    # addModerators - Add moderators to channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param members [T::Array[String]] Member IDs to promote to moderator
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, members: T::Array[String]).returns(StreamChat::StreamResponse) }
    def add_moderators(filter, members)
      @client.update_channels_batch(
        {
          operation: 'addModerators',
          filter: filter,
          members: members
        }
      )
    end

    # demoteModerators - Remove moderator role from members in channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param members [T::Array[String]] Member IDs to demote
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, members: T::Array[String]).returns(StreamChat::StreamResponse) }
    def demote_moderators(filter, members)
      @client.update_channels_batch(
        {
          operation: 'demoteModerators',
          filter: filter,
          members: members
        }
      )
    end

    # assignRoles - Assign roles to members in channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param members [T::Array[StringKeyHash]] Members with role assignments
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, members: T::Array[StringKeyHash]).returns(StreamChat::StreamResponse) }
    def assign_roles(filter, members)
      @client.update_channels_batch(
        {
          operation: 'assignRoles',
          filter: filter,
          members: members
        }
      )
    end

    # Visibility operations

    # hide - Hide channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash).returns(StreamChat::StreamResponse) }
    def hide(filter)
      @client.update_channels_batch(
        {
          operation: 'hide',
          filter: filter
        }
      )
    end

    # show - Show channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash).returns(StreamChat::StreamResponse) }
    def show(filter)
      @client.update_channels_batch(
        {
          operation: 'show',
          filter: filter
        }
      )
    end

    # archive - Archive channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash).returns(StreamChat::StreamResponse) }
    def archive(filter)
      @client.update_channels_batch(
        {
          operation: 'archive',
          filter: filter
        }
      )
    end

    # unarchive - Unarchive channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash).returns(StreamChat::StreamResponse) }
    def unarchive(filter)
      @client.update_channels_batch(
        {
          operation: 'unarchive',
          filter: filter
        }
      )
    end

    # Data operations

    # updateData - Update data on channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param data [StringKeyHash] Data to update
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, data: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update_data(filter, data)
      @client.update_channels_batch(
        {
          operation: 'updateData',
          filter: filter,
          data: data
        }
      )
    end

    # addFilterTags - Add filter tags to channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param tags [T::Array[String]] Tags to add
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, tags: T::Array[String]).returns(StreamChat::StreamResponse) }
    def add_filter_tags(filter, tags)
      @client.update_channels_batch(
        {
          operation: 'addFilterTags',
          filter: filter,
          filter_tags_update: tags
        }
      )
    end

    # removeFilterTags - Remove filter tags from channels matching the filter
    # @param filter [StringKeyHash] Filter to select channels
    # @param tags [T::Array[String]] Tags to remove
    # @return [StreamChat::StreamResponse] The server response
    sig { params(filter: StringKeyHash, tags: T::Array[String]).returns(StreamChat::StreamResponse) }
    def remove_filter_tags(filter, tags)
      @client.update_channels_batch(
        {
          operation: 'removeFilterTags',
          filter: filter,
          filter_tags_update: tags
        }
      )
    end
  end
end

