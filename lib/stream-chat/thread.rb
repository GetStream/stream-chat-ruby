# typed: strict
# frozen_string_literal: true

require 'stream-chat/client'
require 'stream-chat/errors'
require 'stream-chat/util'
require 'stream-chat/types'

module StreamChat
  class Thread
    extend T::Sig

    sig { returns(StreamChat::Client) }
    attr_reader :client

    sig { params(client: StreamChat::Client).void }
    def initialize(client)
      @client = client
    end

    # Queries threads based on filter conditions and sort parameters.
    #
    # The queryThreads endpoint allows you to list and paginate threads. The
    # endpoint supports filtering on numerous criteria and sorting by various fields.
    # This endpoint is useful for displaying threads in a chat application.
    #
    # @param [StringKeyHash] filter MongoDB-style filter conditions
    # @param [T.nilable(T::Hash[String, Integer])] sort Sort parameters
    # @param [T.untyped] options Additional options like limit, offset, next, etc.
    # @return [StreamChat::StreamResponse]
    sig { params(filter: StringKeyHash, sort: T.nilable(T::Hash[String, Integer]), options: T.untyped).returns(StreamChat::StreamResponse) }
    def query_threads(filter = {}, sort: nil, **options)
      params = {}.merge(options).merge({
        filter: filter,
        sort: StreamChat.get_sort_fields(sort)
      })

      @client.post('threads', data: params)
    end
  end
end 