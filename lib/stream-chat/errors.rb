# lib/errors.rb

module StreamChat
  class StreamAPIException < StandardError
    
    def initialize(response)
      @response = response
      p response
      begin
        parsed_response = JSON.parse(response.body)
        @json_response = true
        @error_code = parsed_response.fetch("data", {})
          .fetch("code", "unknown")
        @error_message = parsed_response.fetch("data", {})
          .fetch("message", "unknown")
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
  end
  class StreamChannelException < StandardError; end
end
