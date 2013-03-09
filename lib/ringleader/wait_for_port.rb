module Ringleader
  class WaitForPort
    include Celluloid
    include Celluloid::Logger

    def initialize(host, port, app)
      @host, @port, @app = host, port, app
      async.wait
    end

    def wait
      begin
        TCPSocket.new @host, @port
      rescue Errno::ECONNREFUSED
        sleep 0.5
        debug "#{@host}:#{@port} not open yet"
        retry
      end
      debug "#{@host}:#{@port} open"
      @app.async.port_opened
      terminate
    end
  end
end
