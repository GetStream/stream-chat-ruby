# typed: strict
# frozen_string_literal: true

module StreamChat
  extend T::Sig
  # For now we disable runtime type checks.
  # We will enable it with a major bump in the future,
  # but for now, let's just run a static type check.

  StringKeyHash = T.type_alias { T::Hash[T.any(String, Symbol), T.untyped] }
  SortArray = T.type_alias { T::Array[{ field: String, direction: Integer }] }
end
