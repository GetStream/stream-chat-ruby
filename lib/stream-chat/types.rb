# frozen_string_literal: true

# lib/util.rb
# typed: true
module StreamChat
  extend T::Sig
  T::Configuration.default_checked_level = :never
  # For now we disable runtime type checks.
  # We will enable it with a major bump in the future,
  # but for now, let's just run a static type check.

  StringKeyDictionary = T.type_alias { T::Hash[T.any(String, Symbol), T.untyped] }
end
