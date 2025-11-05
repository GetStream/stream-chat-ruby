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
  def self.normalize_timestamp(t)
    case t
    when DateTime then t.rfc3339
    when Time then t.iso8601
    else t
    end
  end
end
