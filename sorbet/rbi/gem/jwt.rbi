# typed: strict

module JWT
  sig { params(payload: T::Hash[Object, Object], key: String, algorithm: String).returns(String) }
  def self.encode(payload, key, algorithm); end

  sig { params(jwt: String, key: String).returns(T::Hash[Object, Object]) }
  def self.decode(jwt, key); end
end
