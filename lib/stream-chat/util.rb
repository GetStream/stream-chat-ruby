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
end
