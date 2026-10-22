# frozen_string_literal: true

require 'socket'
require 'tempfile'
require 'stream-chat'

# Exercises StreamChat::RetryMiddleware through the real client stack
# (Faraday + net_http_persistent) against a local TLS server. No network
# access or API credentials needed.
describe StreamChat::RetryMiddleware do
  let(:server) { TLSTestServer.new }
  let(:client) { tls_client(server.url) }

  after { server.close }

  def tls_client(url, timeout: 3.0)
    client = StreamChat::Client.new('key', 'secret', timeout, base_url: url)
    # The test server uses a self-signed certificate.
    client.conn.ssl.verify = false
    client
  end

  # Opens a pooled keep-alive connection, then has the server close it without
  # a TLS close_notify, the way the load balancer front end drops connections.
  # Depending on the OpenSSL build, the next request either fails in
  # Net::HTTP#begin_transport (and the middleware retries it) or Net::HTTP sees
  # a clean EOF and reconnects by itself. Either way the request must succeed
  # and reach the server exactly once, which is what these specs assert.
  def make_pooled_connection_stale
    server.script(:respond_close)
    client.get('warmup')
    sleep 0.3 # let the server's close reach the client socket
    server.requests
  end

  def open_pooled_connection
    client.get('warmup')
    server.requests
  end

  # How a dropped connection surfaces depends on the Ruby/OpenSSL build:
  # Faraday::SSLError ("unexpected eof") on some, Faraday::ConnectionFailed
  # (EOFError) on others. Callers get whichever the adapter raises.
  def expect_transport_error(error)
    expect(error).to be_a(Faraday::SSLError).or be_a(Faraday::ConnectionFailed)
  end

  def closed_port
    TCPServer.new('127.0.0.1', 0).then do |s|
      s.addr[1].tap { s.close }
    end
  end

  context 'when the pooled connection went stale' do
    it 'succeeds with a POST, and the server receives it once' do
      make_pooled_connection_stale

      response = client.post('messages', data: { message: { text: 'hi' } })

      expect(response['duration']).to eq('1ms')
      requests = server.requests
      expect(requests.map(&:http_method)).to eq(['POST'])
      expect(JSON.parse(requests.first.body)).to eq('message' => { 'text' => 'hi' })
    end

    it 'succeeds with a GET, and the server receives it once' do
      make_pooled_connection_stale

      client.get('channels')

      expect(server.requests.map(&:http_method)).to eq(['GET'])
    end

    it 'succeeds with a multipart upload, and the server receives the full body once' do
      make_pooled_connection_stale
      content = "line of the uploaded file\n" * 4096
      file = Tempfile.new('upload')
      file.write(content)
      file.close

      client.send_file('uploads', file.path, { 'id' => 'u1' }, 'text/plain')

      requests = server.requests
      expect(requests.map(&:http_method)).to eq(['POST'])
      body = requests.first.body
      expect(body.bytesize).to eq(requests.first.headers['content-length'].to_i)
      expect(body).to include(content)
      expect(body).to include('{"id":"u1"}')
      boundary = requests.first.headers['content-type'][/boundary=(\S+)/, 1]
      expect(body).to end_with("--#{boundary}--\r\n")
    ensure
      file&.unlink
    end
  end

  context 'when the request body is an IO' do
    # Connection refused fails before anything is sent, the same way on every
    # platform, so it isolates the body check. A counting middleware placed
    # after the retry middleware sees each attempt.
    def refused_attempts(body)
      refused = tls_client("https://127.0.0.1:#{closed_port}")
      attempts = 0
      counter = Class.new(Faraday::Middleware) do
        define_method(:call) do |env|
          attempts += 1
          app.call(env)
        end
      end
      refused.conn.builder.insert_after(StreamChat::RetryMiddleware, counter)

      expect do
        refused.conn.post('messages', body, 'Content-Length' => '7', 'Content-Type' => 'application/json')
      end.to raise_error(Faraday::ConnectionFailed, /connection refused/)
      attempts
    end

    it 'does not retry a body that cannot be rewound' do
      body = Class.new do
        attr_reader :reads

        def initialize(data)
          @io = StringIO.new(data)
          @reads = 0
        end

        def read(*args)
          @reads += 1
          @io.read(*args)
        end
      end.new('{"a":1}')

      expect(refused_attempts(body)).to eq(1)
      expect(body.reads).to eq(0)
    end

    it 'retries a body that can be rewound' do
      expect(refused_attempts(StringIO.new('{"a":1}'))).to eq(3)
    end
  end

  context 'when the connection drops after the request was sent' do
    it 'retries a GET, and the server receives it twice' do
      open_pooled_connection
      server.script(:drop)

      client.get('channels')

      expect(server.requests.map(&:http_method)).to eq(%w[GET GET])
    end

    it 'does not retry a POST and raises the transport error' do
      open_pooled_connection
      server.script(:drop)

      expect { client.post('messages', data: { message: { text: 'hi' } }) }
        .to(raise_error { |e| expect_transport_error(e) })
      expect(server.requests.map(&:http_method)).to eq(['POST'])
    end

    it 'stops after 3 attempts' do
      open_pooled_connection
      server.script(:drop, :drop, :drop, :drop)

      expect { client.get('channels') }.to(raise_error { |e| expect_transport_error(e) })
      expect(server.requests.map(&:http_method)).to eq(%w[GET GET GET])
    end
  end

  context 'when the connection is refused' do
    it 'retries a POST once the server is listening' do
      port = closed_port
      late_client = tls_client("https://127.0.0.1:#{port}")
      late_server = nil
      starter = Thread.new do
        sleep 0.05 # first attempt is refused; the first retry waits >= 100ms
        late_server = TLSTestServer.new(port: port)
      end

      late_client.post('messages', data: { message: { text: 'hi' } })

      starter.join
      expect(late_server.requests.map(&:http_method)).to eq(['POST'])
    ensure
      starter&.join
      late_server&.close
    end
  end

  context 'when the server answers or times out' do
    it 'does not retry an HTTP 500' do
      open_pooled_connection
      server.script(:server_error)

      expect { client.get('channels') }.to raise_error(StreamChat::StreamAPIException)
      expect(server.requests.map(&:http_method)).to eq(['GET'])
    end

    it 'does not retry a read timeout' do
      slow_client = tls_client(server.url, timeout: 0.5)
      server.script(:stall)

      expect { slow_client.get('channels') }.to raise_error(Faraday::TimeoutError)
      expect(server.requests.map(&:http_method)).to eq(['GET'])
    end
  end
end
