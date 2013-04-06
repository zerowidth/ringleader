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
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
        debug "#{@host}:#{@port} not open yet"
        sleep 0.5
        retry
      rescue IOError, SystemCallError => e
        error "unexpected error while waiting for port: #{e}"
        sleep 0.5
        retry
      end
      debug "#{@host}:#{@port} open"
      @app.async.port_opened
      terminate
    end
  end
end
