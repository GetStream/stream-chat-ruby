# typed: strict
# frozen_string_literal: true

require 'stream-chat/types'

module StreamChat
  extend T::Sig

  sig { params(sort: T.nilable(T::Hash[String, Integer])).returns(SortArray) }
  def self.get_sort_fields(sort)
    sort_fields = T.let([], SortArray)
    sort&.each do |k, v|
      sort_fields << { field: k, direction: v }
    end
    sort_fields
  end

  # Normalizes a timestamp to RFC 3339 / ISO 8601 string format.
  sig { params(timestamp: T.any(DateTime, Time, String)).returns(String) }
  def self.normalize_timestamp(timestamp)
    case timestamp
    when DateTime then timestamp.rfc3339
    when Time then timestamp.iso8601
    else timestamp
    end
  end
end
