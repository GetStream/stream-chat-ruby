# typed: strict
# frozen_string_literal: true

module StreamChat
  class StreamAPIException < StandardError
    extend T::Sig
    # For now we disable runtime type checks.
    # We will enable it with a major bump in the future,
    # but for now, let's just run a static type check.

    T::Sig::WithoutRuntime.sig { returns(Integer) }
    attr_reader :error_code

    T::Sig::WithoutRuntime.sig { returns(String) }
    attr_reader :error_message

    T::Sig::WithoutRuntime.sig { returns(T::Boolean) }
    attr_reader :json_response

    T::Sig::WithoutRuntime.sig { returns(Faraday::Response) }
    attr_reader :response

    T::Sig::WithoutRuntime.sig { params(response: Faraday::Response).void }
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

    T::Sig::WithoutRuntime.sig { returns(String) }
    def message
      if @json_response
        "StreamChat error code #{@error_code}: #{@error_message}"
      else
        "StreamChat error HTTP code: #{@response.status}"
      end
    end

    T::Sig::WithoutRuntime.sig { returns(String) }
    def to_s
      message
    end
  end

  class StreamChannelException < StandardError; end
end
