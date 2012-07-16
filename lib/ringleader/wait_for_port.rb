module Ringleader
  class WaitForPort
    include Celluloid
    include Celluloid::Logger

    def initialize(host, port, app)
      @host, @port, @app = host, port, app
      wait!
    end

    def wait
      begin
        socket = TCPSocket.new @host, @port
      rescue Errno::ECONNREFUSED
        sleep 0.5
        debug "#{@host}:#{@port} not open yet"
        retry
      end
      debug "#{@host}:#{@port} open"
      @app.port_opened!
      terminate
    end
  end
end
