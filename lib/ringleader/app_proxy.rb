module Ringleader

  # Proxy for an application running on a given port.
  class AppProxy
    include Celluloid::IO
    include Celluloid::Logger

    attr_reader :config

    # Create a new AppProxy instance
    #
    # app    - the application to proxy to
    # config - a configuration object for this app
    def initialize(app, config)
      @config = config
      @app = app
      @server = TCPServer.new config.hostname, config.server_port
      run!
    rescue Errno::EADDRINUSE
      error "could not bind to #{config.hostname}:#{config.server_port} for #{config.name}!"
    end

    def finalize
      @server.close if @server
    end

    def run
      start_activity_timer if config.idle_timeout > 0
      info "server listening for connections for #{config.name} on #{config.hostname}:#{config.server_port}"
      loop { handle_connection! @server.accept }
    end

    def handle_connection(socket)
      _, port, host = socket.peeraddr
      debug "received connection from #{host}:#{port}"

      started = @app.start
      if started
        proxy_to_app! socket
        @activity_timer.reset if @activity_timer
      else
        error "could not start app"
        socket.close
      end
    end

    def proxy_to_app(socket)
      SocketProxy.new socket, config.hostname, config.app_port
    end

    def start_activity_timer
      @activity_timer = every config.idle_timeout do
        if @app.running?
          info "#{config.name} has been idle for #{config.idle_timeout} seconds, shutting it down"
          @app.stop
        end
      end
    end
  end

end
