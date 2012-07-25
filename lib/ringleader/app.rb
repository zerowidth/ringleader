module Ringleader

  # Represents a running instance of an application.
  class App
    include Celluloid
    include Celluloid::Logger
    include NameLogger

    attr_reader :config

    # Create a new App instance.
    #
    # config - a configuration object for this app
    def initialize(config)
      @config = config
      @starting = @running = false
      @restart_file = File.expand_path(config.dir + "/tmp/restart.txt")
      @mtime = File.exist?(@restart_file) ? File.mtime(@restart_file).to_i : 0
    end

    def persistent?
      !@config.app_port
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
      if restart?
        info "tmp/restart.txt modified, restarting..."
        stop
      end

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
    # Sends a SIGTERM to the app's process, and expects it to exit like a sane
    # and well-behaved application within 30 seconds before sending a SIGKILL.
    def stop
      return unless @pid

      info "stopping #{@pid}"
      @master.close unless @master.closed?
      debug "kill -TERM #{@pid}"
      Process.kill "TERM", -@pid

      kill = after 30 do
        if @running
          warn "process #{@pid} did not shut down cleanly, killing it"
          debug "kill -KILL #{@pid}"
          Process.kill "KILL", -@pid
        end
      end

      wait :running # wait for the exit callback
      kill.cancel

    rescue Errno::ESRCH, Errno::EPERM
      exited
    end

    # Internal: callback for when the application port has opened
    def port_opened
      info "listening on #{config.hostname}:#{config.app_port}"
      signal :running, true
    end

    # Internal: callback for when the process has exited.
    def exited
      debug "pid #{@pid} has exited"
      info "exited."
      @running = false
      @pid = nil
      @wait_for_port.terminate if @wait_for_port && @wait_for_port.alive?
      @wait_for_exit.terminate if @wait_for_exit.alive?
      signal :running, false
    end

    # Private: start the application process and associated infrastructure
    #
    # Intended to be synchronous, as it blocks until the app has started (or
    # failed to start).
    #
    # Returns true if the app started, false if not.
    def start_app
      @starting = true
      info "starting process `#{config.command}`"

      # give the child process a terminal so output isn't buffered
      @master, slave = PTY.open
      @pid = Process.spawn %Q(bash -c "#{config.command}"),
        :in => slave,
        :out => slave,
        :err => slave,
        :chdir => config.dir,
        :pgroup => true
      slave.close
      proxy_output @master
      debug "started with pid #{@pid}"

      @wait_for_exit = WaitForExit.new @pid, Actor.current

      if persistent?
        @running = true
      else
        @wait_for_port = WaitForPort.new config.hostname, config.app_port, Actor.current

        timer = after config.startup_timeout do
          warn "application startup took more than #{config.startup_timeout}"
          stop!
        end

        @running = wait :running
        @starting = false
        timer.cancel
      end

      @running
    rescue Errno::ENOENT
      debug "could not start process `#{config.command}`"
      false
    end

    # Private: proxy output streams to the logger.
    #
    # Fire and forget, runs in its own thread.
    def proxy_output(input)
      Thread.new do
        until input.eof?
          info input.gets.strip
        end
      end
    end

    # Check the mtime of the tmp/restart.txt file. If modified, restart the app.
    def restart?
      if File.exist?(@restart_file)
        new_mtime = File.mtime(@restart_file).to_i
        if new_mtime > @mtime
          @mtime = new_mtime
          true
        end
      end
    end

  end

end
