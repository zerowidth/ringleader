require "celluloid/io"

require "proxy_server"

class AppProxyServer < ProxyServer
  include Celluloid::IO

  def initialize(host, port, dest_port, cmd)
    super host, port, dest_port
    @app = AppProxy.new(cmd, @dest_port)
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr
    debug "received connection from #{host}:#{port}"

    started = @app.start
    if started
      proxy_to_app socket
    else
      error "could not start app"
      @app.reset # try again next time
      socket.close
    end
  end

  def proxy_to_app(socket)
    proxy = SocketProxy.new socket, @host, @dest_port
    debug "got proxy: #{proxy.inspect}"
    if proxy.alive?
      debug "proxy connected, hooray!"
    else
      debug "proxy isn't connected. sad times."
    end
  end
end

class AppProxy
  include Celluloid::Logger

  def initialize(command, port)
    @command, @port = command, port
    @started = nil
  end

  def start
    if @started.nil?
      debug "app starting..."
      sleep 2
      debug "app started."
      @started = true
    else
      debug "app already running"
    end
    true
  end

  def reset
    @started = nil
  end

end

AppProxyServer.new "localhost", 10000, 10001, "lol"
sleep

