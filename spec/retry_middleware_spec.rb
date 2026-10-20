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

  context 'when the pooled connection went stale (request never sent)' do
    it 'retries a POST, and the server receives it once' do
      make_pooled_connection_stale

      response = client.post('messages', data: { message: { text: 'hi' } })

      expect(response['duration']).to eq('1ms')
      requests = server.requests
      expect(requests.map(&:http_method)).to eq(['POST'])
      expect(JSON.parse(requests.first.body)).to eq('message' => { 'text' => 'hi' })
    end

    it 'retries a GET, and the server receives it once' do
      make_pooled_connection_stale

      client.get('channels')

      expect(server.requests.map(&:http_method)).to eq(['GET'])
    end

    it 'retries a multipart upload with the full body' do
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

    it 'does not retry an IO body that cannot be rewound' do
      make_pooled_connection_stale
      body = Class.new do
        def initialize(data)
          @io = StringIO.new(data)
        end

        def read(*args)
          @io.read(*args)
        end
      end.new('{"a":1}')

      expect do
        client.conn.post('messages', body, 'Content-Length' => '7', 'Content-Type' => 'application/json')
      end.to raise_error(Faraday::SSLError)
      expect(server.requests).to be_empty
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
        .to raise_error(Faraday::SSLError, /unexpected eof/)
      expect(server.requests.map(&:http_method)).to eq(['POST'])
    end

    it 'stops after 3 attempts' do
      open_pooled_connection
      server.script(:drop, :drop, :drop, :drop)

      expect { client.get('channels') }.to raise_error(Faraday::SSLError)
      expect(server.requests.map(&:http_method)).to eq(%w[GET GET GET])
    end
  end

  context 'when the connection is refused' do
    it 'retries a POST once the server is listening' do
      port = TCPServer.new('127.0.0.1', 0).then do |s|
        s.addr[1].tap { s.close }
      end
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
