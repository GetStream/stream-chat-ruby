# frozen_string_literal: true

# lib/errors.rb

module StreamChat
  class StreamAPIException < StandardError
    attr_reader :error_code
    attr_reader :error_message

    def initialize(response)
      super()
      @response = response
      begin
        parsed_response = JSON.parse(response.body)
        @json_response = true
        @error_code = parsed_response.fetch('code', 'unknown')
        @error_message = parsed_response.fetch('message', 'unknown')
      rescue JSON::ParserError
        @json_response = false
      end
    end

    def message
      if @json_response
        "StreamChat error code #{@error_code}: #{@error_message}"
      else
        "StreamChat error HTTP code: #{@response.status}"
      end
    end

    def json_response?
      @json_response
    end

    def to_s
      message
    end
  end

  class StreamChannelException < StandardError; end
end
