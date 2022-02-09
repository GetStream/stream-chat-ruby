# typed: strict

class Object < BasicObject
  include Kernel

  sig { params(_: T.untyped).returns(String) }
  def to_json(*_); end
end
