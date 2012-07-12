require "celluloid/io"

class ProxyServer
  include Celluloid::IO
  include Celluloid::Logger

  def initialize(host, port, dest_port)
    @host, @port, @dest_port = host, port, dest_port
    @server = TCPServer.new(host, port)
    run!
  end

  def finalize
    @server.close if @server
  end

  def run
    debug "server listening for connections on port #{@port}"
    loop { handle_connection! @server.accept }
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr
    debug "received connection from #{host}:#{port}"
    SocketProxy.new socket, @host, @dest_port
  end
end

class SocketProxy
  include Celluloid::IO
  include Celluloid::Logger

  def initialize(server_connection, host, port)
    @server_connection = server_connection

    debug "proxying to #{host}:#{port}"
    @socket = TCPSocket.new(host, port)

    proxy! @socket, @server_connection
    proxy! @server_connection, @socket
    wait_for_disconnect!
  rescue Errno::ECONNREFUSED
    error "could not proxy to #{host}:#{port}"
    @server_connection.close
    terminate
  end

  def wait_for_disconnect
    sleep 1 until [@socket, @server_connection].any? { |s| s.closed? }
    terminate
  end

  def proxy(from, to)
    ::IO.copy_stream from, to
  rescue IOError
    # from or to were closed
  ensure
    from.close unless from.closed?
    to.close unless to.closed?
  end
end

# ProxyServer.new "localhost", 10000, 10001

# trap("INT") do
#   exit
# end

# sleep
