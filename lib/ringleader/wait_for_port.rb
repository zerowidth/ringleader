module Ringleader
  class WaitForPort
    include Celluloid

    def initialize(host, port, app)
      @host, @port, @app = host, port, app
      wait!
    end

    def wait
      begin
        socket = TCPSocket.new @host, @port
      rescue Errno::ECONNREFUSED
        sleep 0.5
        retry
      end
      @app.port_opened!
      terminate
    end
  end
end
