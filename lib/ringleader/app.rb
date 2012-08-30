module Ringleader

  # A configured application.
  #
  # Listens on a port, starts and runs the app process on demand, and proxies
  # network data to the process.
  class App
    include Celluloid::IO
    include Celluloid::Logger

    def initialize(config)
      @config = config
      @process = Process.new(config)
      enable! unless config.disabled
    end

    def name
      @config.name
    end

    def enabled?
      @enabled
    end

    def running?
      @process.running?
    end

    def start
      return if @process.running?
      info "starting #{@config.name}..."
      if @process.start
        start_activity_timer
      end
    end

    def stop
      return unless @process.running?
      info "stopping #{@config.name}..."
      stop_activity_timer
      @process.stop
    end

    def restart
      stop
      start
    end

    def enable
      return if @server
      @server = TCPServer.new @config.host, @config.server_port
      @enabled = true
      run!
    rescue Errno::EADDRINUSE
      error "could not bind to #{@config.host}:#{@config.server_port} for #{@config.name}!"
      @server = nil
    end

    def disable
      info "disabling #{@config.name}..."
      return unless @server
      stop_activity_timer
      @process.stop
      @server.close
      @server = nil
      @enabled = false
    end

    def finalize
      @server.close if @server
    end

    def run
      info "listening for connections for #{@config.name} on #{@config.host}:#{@config.server_port}"
      loop { handle_connection! @server.accept }
    rescue IOError
      @server.close if @server
    end

    def handle_connection(socket)
      _, port, host = socket.peeraddr
      debug "received connection from #{host}:#{port}"

      started = @process.start
      if started
        proxy_to_app! socket
        reset_activity_timer
      else
        error "could not start app"
        socket.close
      end
    end

    def proxy_to_app(socket)
      SocketProxy.new socket, @config.host, @config.app_port
    end

    def start_activity_timer
      return if @activity_timer || @config.idle_timeout == 0
      @activity_timer = every @config.idle_timeout do
        if @process.running?
          info "#{@config.name} has been idle for #{@config.idle_timeout} seconds, shutting it down"
          @process.stop
        end
      end
    end

    def reset_activity_timer
      start_activity_timer
      @activity_timer.reset if @activity_timer
    end

    def stop_activity_timer
      if @activity_timer
        @activity_timer.cancel
        @activity_timer = nil
      end
    end

  end
end
