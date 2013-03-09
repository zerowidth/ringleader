module Ringleader

  # Proxies data to and from a server socket to a new downstream connection.
  #
  # This is fire-and-forget: create the SocketProxy and off it goes.
  #
  # Closes the server connection when proxying is complete and terminates the
  # actor.
  class SocketProxy
    include Celluloid::IO
    include Celluloid::Logger

    def initialize(upstream, host, port)
      @upstream = upstream

      debug "proxying to #{host}:#{port}"
      @socket = TCPSocket.new(host, port)

      async.proxy @socket, @upstream
      async.proxy @upstream, @socket

    rescue Errno::ECONNREFUSED
      error "could not proxy to #{host}:#{port}"
      @upstream.close
      terminate
    end

    def proxy(from, to)
      ::IO.copy_stream from, to
    rescue IOError
      # from or to were closed
    ensure
      from.close unless from.closed?
      to.close unless to.closed?
      terminate
    end
  end

end
