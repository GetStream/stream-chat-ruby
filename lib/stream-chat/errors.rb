# typed: strict
# frozen_string_literal: true

module StreamChat
  class StreamAPIException < StandardError
    extend T::Sig

    sig { returns(Integer) }
    attr_reader :error_code

    sig { returns(String) }
    attr_reader :error_message

    sig { returns(T::Boolean) }
    attr_reader :json_response

    sig { returns(Faraday::Response) }
    attr_reader :response

    sig { params(response: Faraday::Response).void }
    def initialize(response)
      super()
      @response = response
      begin
        parsed_response = JSON.parse(response.body)
        @json_response = T.let(true, T::Boolean)
        @error_code = T.let(parsed_response.fetch('code', 'unknown'), Integer)
        @error_message = T.let(parsed_response.fetch('message', 'unknown'), String)
      rescue JSON::ParserError
        @json_response = false
      end
    end

    sig { returns(String) }
    def message
      if @json_response
        "StreamChat error code #{@error_code}: #{@error_message}"
      else
        "StreamChat error HTTP code: #{@response.status}"
      end
    end

    sig { returns(String) }
    def to_s
      message
    end
  end

  class StreamChannelException < StandardError; end

  # Raised by webhook verify/parse helpers when the HMAC does not match or a
  # gzip/base64/JSON envelope cannot be decoded. The message identifies which
  # failure mode fired; the class-level constants below are the canonical
  # strings for callers that prefer exact-match filtering over substring.
  class InvalidWebhookError < StandardError
    SIGNATURE_MISMATCH = 'signature mismatch'
    INVALID_BASE64 = 'invalid base64 encoding'
    GZIP_FAILED = 'gzip decompression failed'
    INVALID_JSON = 'invalid JSON payload'
  end
end
