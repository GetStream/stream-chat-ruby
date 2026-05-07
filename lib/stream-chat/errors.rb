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

  # Raised when a webhook payload cannot be decoded, decompressed, or its
  # signature does not match the expected HMAC. Carries a human readable
  # reason instead of an HTTP response so it can be raised from the local
  # webhook helpers (decompress / verify) without involving Faraday.
  class WebhookSignatureError < StreamAPIException
    extend T::Sig

    sig { returns(String) }
    attr_reader :reason

    sig { params(reason: String).void }
    def initialize(reason) # rubocop:disable Lint/MissingSuper
      @reason = T.let(reason, String)
      @json_response = T.let(false, T::Boolean)
      @error_code = T.let(0, Integer)
      @error_message = T.let(reason, String)
      StandardError.instance_method(:initialize).bind_call(self, reason)
    end

    sig { returns(String) }
    def message
      @reason
    end

    sig { returns(String) }
    def to_s
      @reason
    end
  end
end
