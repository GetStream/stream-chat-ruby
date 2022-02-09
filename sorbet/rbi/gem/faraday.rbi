# typed: true

# The built-in Faraday types are missing a looooot unfortunately.
# Until they don't improve it, we'll write ours:
# https://github.com/sorbet/sorbet-typed/blob/master/lib/faraday/all/faraday.rbi

module Faraday
  sig do
    params(
      url: T.nilable(String),
      options: Hash,
      block: T.nilable(T.proc.params(env: T.untyped).void)
    ).returns(Faraday::Connection)
  end
  def self.new(url = nil, options = nil, &block); end

  class Request
    sig { returns(T.nilable(T::Hash[String, String])) }
    attr_accessor :headers

    sig { returns(T::Hash[T.untyped, T.untyped]) }
    attr_accessor :params

    sig { returns(T.untyped) }
    attr_accessor :body
  end

  class Response
    sig { returns(T::Hash[String, String]) }
    attr_reader :headers

    sig { returns(Integer) }
    attr_reader :status

    sig { returns(String) }
    attr_reader :body
  end

  class UploadIO
    params(filename_or_io: String, content_type: String)
    def self.new(filename_or_io, content_type); end
  end

  class Connection
    params(
      method: T.any(String, Symbol),
      url: String,
      body: T.any(String, T.nilable(T::Hash[Object, Object])),
      headers: T.nilable(T::Hash[Object, String])
    ).returns(Faraday::Response)
    def run_request(method, url, body, headers); end

    params(
      url: String,
      body: T.any(String, T.nilable(T::Hash[Object, Object])),
      headers: T.nilable(T::Hash[Object, String]),
      block: T.nilable(T.proc.params(req: Faraday::Request).void)
    ).returns(Faraday::Response)
    def post(url, body = nil, headers = nil, &block); end
  end
end
