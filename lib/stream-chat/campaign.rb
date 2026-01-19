# typed: strict
# frozen_string_literal: true

require 'stream-chat/client'
require 'stream-chat/errors'
require 'stream-chat/util'
require 'stream-chat/types'

module StreamChat
  class Campaign
    extend T::Sig

    sig { returns(T.nilable(String)) }
    attr_reader :campaign_id

    sig { returns(T.nilable(StringKeyHash)) }
    attr_reader :data

    sig { params(client: StreamChat::Client, campaign_id: T.nilable(String), data: T.nilable(StringKeyHash)).void }
    def initialize(client, campaign_id = nil, data = nil)
      @client = client
      @campaign_id = campaign_id
      @data = data
    end

    # Creates a campaign.
    #
    # @param [String, nil] campaign_id Optional campaign ID. If provided, sets the campaign_id.
    # @param [StringKeyHash, nil] data Optional campaign data to merge with existing data.
    # @return [StreamChat::StreamResponse] API response
    sig { params(campaign_id: T.nilable(String), data: T.nilable(StringKeyHash)).returns(StreamChat::StreamResponse) }
    def create(campaign_id: nil, data: nil)
      @campaign_id = campaign_id if campaign_id
      @data = merge_campaign_data(@data, data) if data

      state = @client.create_campaign(campaign_id: @campaign_id, data: @data)

      @campaign_id = state['campaign']['id'] if @campaign_id.nil? && state.status_code >= 200 && state.status_code < 300 && state['campaign']
      state
    end

    # Gets a campaign by ID.
    #
    # @return [StreamChat::StreamResponse] API response
    sig { returns(StreamChat::StreamResponse) }
    def get
      raise StreamChannelException, 'campaign does not have an id' if @campaign_id.nil?

      @client.get_campaign(@campaign_id)
    end

    # Updates a campaign.
    #
    # @param [StringKeyHash] data Campaign data to update
    # @return [StreamChat::StreamResponse] API response
    sig { params(data: StringKeyHash).returns(StreamChat::StreamResponse) }
    def update(data)
      raise StreamChannelException, 'campaign does not have an id' if @campaign_id.nil?

      @client.update_campaign(@campaign_id, data)
    end

    # Deletes a campaign.
    #
    # @param [Hash] options Optional deletion options
    # @return [StreamChat::StreamResponse] API response
    sig { params(options: T.untyped).returns(StreamChat::StreamResponse) }
    def delete(**options)
      raise StreamChannelException, 'campaign does not have an id' if @campaign_id.nil?

      @client.delete_campaign(@campaign_id, **options)
    end

    # Starts a campaign.
    #
    # @param [DateTime, Time, String, nil] scheduled_for Optional scheduled start time
    # @param [DateTime, Time, String, nil] stop_at Optional scheduled stop time
    # @return [StreamChat::StreamResponse] API response
    sig { params(scheduled_for: T.nilable(T.any(DateTime, Time, String)), stop_at: T.nilable(T.any(DateTime, Time, String))).returns(StreamChat::StreamResponse) }
    def start(scheduled_for: nil, stop_at: nil)
      raise StreamChannelException, 'campaign does not have an id' if @campaign_id.nil?

      @client.start_campaign(@campaign_id, scheduled_for: scheduled_for, stop_at: stop_at)
    end

    # Stops a campaign.
    #
    # @return [StreamChat::StreamResponse] API response
    sig { returns(StreamChat::StreamResponse) }
    def stop
      raise StreamChannelException, 'campaign does not have an id' if @campaign_id.nil?

      @client.stop_campaign(@campaign_id)
    end

    private

    # Merges two campaign data hashes.
    #
    # @param [StringKeyHash, nil] data1 First campaign data hash
    # @param [StringKeyHash, nil] data2 Second campaign data hash
    # @return [StringKeyHash] Merged campaign data
    sig { params(data1: T.nilable(StringKeyHash), data2: T.nilable(StringKeyHash)).returns(StringKeyHash) }
    def merge_campaign_data(data1, data2)
      return T.must(data2) if data1.nil?
      return data1 if data2.nil?

      data1.merge(data2)
    end
  end
end
