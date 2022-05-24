# typed: strict
# frozen_string_literal: true

module StreamChat
  extend T::Sig

  StringKeyHash = T.type_alias { T::Hash[T.any(String, Symbol), T.untyped] }
  SortArray = T.type_alias { T::Array[{ field: String, direction: Integer }] }
end
