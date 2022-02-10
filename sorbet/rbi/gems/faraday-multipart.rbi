# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: strict
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/faraday-multipart/all/faraday-multipart.rbi
#
# faraday-multipart-1.0.3

module Faraday
end
module Faraday::Multipart
end
class Faraday::Multipart::CompositeReadIO
  def advance_io; end
  def close; end
  def current_io; end
  def ensure_open_and_readable; end
  def initialize(*parts); end
  def length; end
  def read(length = nil, outbuf = nil); end
  def rewind; end
end
class Faraday::Multipart::ParamPart
  def content_id; end
  def content_type; end
  def headers; end
  def initialize(value, content_type, content_id = nil); end
  def to_part(boundary, key); end
  def value; end
end
class Faraday::Multipart::Middleware < Faraday::Request::UrlEncoded
  def call(env); end
  def create_multipart(env, params); end
  def has_multipart?(obj); end
  def initialize(app = nil, options = nil); end
  def part(boundary, key, value); end
  def process_params(params, prefix = nil, pieces = nil, &block); end
  def process_request?(env); end
  def unique_boundary; end
end
