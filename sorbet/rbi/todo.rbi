# typed: strong

module RSpec::Expectations::ExpectationNotMetError; end
module Faraday::Request; end
module Faraday::Response; end

module Faraday::UploadIO
  params(filename_or_io: String, content_type: String)
  def self.new(filename_or_io, content_type); end
end
