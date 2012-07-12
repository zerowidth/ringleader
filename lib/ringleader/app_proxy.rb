module Ringleader

  # Proxy for an application running on a given port.
  class AppProxy
    include Celluloid::IO
    include Celluloid::Logger

    def initialize(host, port, dest_port, app)
      @host, @port, @dest_port = host, port, dest_port
      @server = TCPServer.new(host, port)
      @app = app
      run!
    end

    def finalize
      @server.close if @server
    end

    def run
      start_activity_timer
      debug "server listening for connections on port #{@port}"
      loop { handle_connection! @server.accept }
    end

    def handle_connection(socket)
      _, port, host = socket.peeraddr
      # debug "received connection from #{host}:#{port}"

      started = @app.start
      if started
        proxy_to_app! socket
        @activity_timer.reset
      else
        error "could not start app"
        socket.close
      end
    end

    def proxy_to_app(socket)
      SocketProxy.new socket, @host, @dest_port
    end

    def start_activity_timer
      @activity_timer = every 10 do
        if @app.running?
          debug "app has been idle, shutting it down"
          @app.stop
        end
      end
    end
  end

end
