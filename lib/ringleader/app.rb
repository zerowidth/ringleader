module Ringleader

  # Represents a running instance of an application.
  class App
    include Celluloid
    include Celluloid::Logger

    # Create a new App instance.
    #
    # cmd  - the command to run
    # host - the host the app is running on
    # port - the port the app is expected to listen on
    def initialize(cmd, host, port)
      @cmd = cmd
      @host = host
      @port = port
      @starting = @running = false
    end

    # Public: query if the app is running
    def running?
      @running
    end

    # Public: start the application.
    #
    # This method is intended to be used synchronously. If the app is already
    # running, it'll return immediately. If the app hasn't been started, or is
    # in the process of starting, this method blocks until it starts or fails to
    # start correctly.
    #
    # Returns true if the app started, false if not.
    def start
      if @running
        true
      elsif @starting
        wait :running
      else
        start_app
      end
    end

    # Public: stop the application.
    #
    # Sends a SIGHUP to the app's process, and expects it to exit like a sane
    # and well-behaved application within 30 seconds before sending a SIGTERM.
    def stop
      return unless @running

      debug "stopping #{@cmd}"
      Process.kill "SIGHUP", @pid

      timer = after 30 do
        if @running
          warn "process #{@pid} did not shut down cleanly, killing it"
          Process.kill "SIGTERM", @pid
        end
      end

      wait :running # wait for the exit callback
      timer.cancel
    rescue Errno::ESRCH, Errno::EPERM
      exited
    end

    # Internal: callback for when the application port has opened
    def port_opened
      info "process #{@pid} has started"
      signal :running, true
    end

    # Internal: callback for when the process has exited.
    def exited
      info "process #{@pid} has gone away"
      signal :running, false
      @running = false
      @wait_for_port.terminate if @wait_for_port.alive?
      @wait_for_exit.terminate if @wait_for_exit.alive?
    end

    # Private: start the application process and associated infrastructure
    #
    # Intended to be synchronous, as it blocks until the app has started (or
    # failed to start).
    #
    # Returns true if the app started, false if not.
    def start_app
      @starting = true
      debug "starting process: #{@cmd}"
      reader, writer = ::IO.pipe
      @pid = Process.spawn @cmd, :out => writer, :err => writer
      proxy_output reader
      debug "started with pid #{@pid}"

      @wait_for_exit = WaitForExit.new @pid, Actor.current
      @wait_for_port = WaitForPort.new @host, @port, Actor.current

      timer = after(10) { warn "application startup took too long"; stop! }

      @running = wait :running
      @starting = false
      timer.cancel

      @running
    rescue Errno::ENOENT
      debug "could not start process: #{@cmd}"
      false
    end

    # Private: proxy output streams to the logger.
    #
    # Fire and forget, runs in its own thread.
    def proxy_output(input)
      Thread.new do
        until input.eof?
          info "#{@pid} | " + input.gets.strip
        end
      end
    end
  end

end
