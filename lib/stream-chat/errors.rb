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

      # Seed defaults first so the typed readers never return nil. A 5xx can
      # arrive with an empty or non-JSON body (e.g. a load balancer emitting a
      # bare 503), and an error envelope may omit "code"/"message" or send a
      # non-integer "code". Without these defaults, reading error_code on such
      # an exception raised a Sorbet TypeError that masked the real HTTP error.
      @json_response = T.let(false, T::Boolean)
      @error_code = T.let(-1, Integer)
      @error_message = T.let('unknown', String)

      begin
        parsed_response = JSON.parse(response.body)
      rescue JSON::ParserError
        return
      end
      return unless parsed_response.is_a?(Hash)

      @json_response = true
      code = parsed_response['code']
      @error_code = code if code.is_a?(Integer)
      msg = parsed_response['message']
      @error_message = msg if msg.is_a?(String)
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
