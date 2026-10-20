# frozen_string_literal: true

require 'openssl'
require 'socket'

# A local HTTPS server for transport-level tests. Each request it reads is
# handled by the next scripted action (default :respond):
#   :respond       - answer 200 and keep the connection open
#   :respond_close - answer 200, then close the TCP socket without a TLS
#                    close_notify, leaving the client's pooled connection stale
#   :drop          - read the request, close the TCP socket without answering
#   :server_error  - answer 500 with a Stream error body
#   :stall         - read the request and never answer (client read timeout)
# Every request read is recorded in #requests, including dropped ones.
class TLSTestServer
  Request = Struct.new(:http_method, :path, :headers, :body, keyword_init: true)

  attr_reader :port

  def initialize(port: 0)
    @tcp = TCPServer.new('127.0.0.1', port)
    @port = @tcp.addr[1]
    @ssl = OpenSSL::SSL::SSLServer.new(@tcp, self.class.ssl_context)
    @ssl.start_immediately = true
    @actions = Queue.new
    @requests = Queue.new
    @threads = []
    @thread = Thread.new { accept_loop }
  end

  def self.ssl_context
    @ssl_context ||= begin
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=localhost')
      cert.public_key = key.public_key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      cert.sign(key, OpenSSL::Digest.new('SHA256'))
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert = cert
      ctx.key = key
      ctx
    end
  end

  def url
    "https://127.0.0.1:#{@port}"
  end

  def script(*actions)
    actions.each { |a| @actions << a }
  end

  # Returns and clears the requests recorded so far.
  def requests
    out = []
    out << @requests.pop until @requests.empty?
    out
  end

  def close
    @thread.kill
    @threads.each(&:kill)
    @tcp.close
  end

  private

  def accept_loop
    loop do
      conn = begin
        @ssl.accept
      rescue OpenSSL::SSL::SSLError, SystemCallError, IOError
        next
      end
      @threads << Thread.new(conn) { |c| serve(c) }
    end
  end

  def serve(conn)
    loop do
      request = read_request(conn)
      break unless request

      @requests << request
      break unless handle(conn, @actions.empty? ? :respond : @actions.pop)
    end
  rescue StandardError
    nil
  end

  # Returns whether the connection stays open for another request.
  def handle(conn, action)
    case action
    when :drop
      conn.to_io.close
      false
    when :stall
      sleep 5
      false
    when :server_error
      write_response(conn, '500 Internal Server Error', '{"code":-1,"message":"boom","StatusCode":500}')
      true
    else
      write_response(conn, '200 OK', '{"duration":"1ms"}')
      return true unless action == :respond_close

      sleep 0.1
      conn.to_io.close
      false
    end
  end

  def read_request(conn)
    head = +''
    head << conn.readpartial(65_536) until head.include?("\r\n\r\n")
    head, body = head.split("\r\n\r\n", 2)
    lines = head.split("\r\n")
    method, path = lines.shift.split
    headers = lines.to_h do |l|
      k, v = l.split(':', 2)
      [k.downcase, v.strip]
    end
    length = headers['content-length'].to_i
    body = body.to_s
    body << conn.readpartial(65_536) while body.bytesize < length
    Request.new(http_method: method, path: path, headers: headers, body: body)
  rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
    nil
  end

  def write_response(conn, status, body)
    conn.write("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
  end
end
