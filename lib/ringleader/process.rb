module Ringleader

  # Represents an instance of a configured application.
  class Process
    include Celluloid
    include Celluloid::Logger
    include NameLogger

    attr_reader :config

    RBENV_CLEAN_ENV_VARS = %w(RBENV_VERSION RBENV_DIR GEM_HOME)

    # Create a new App instance.
    #
    # config - a configuration object for this app
    def initialize(config)
      @config = config
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
        if already_running?
          warn "#{config.name} already running on port #{config.app_port}"
          return true
        else
          start_app
        end
      end
    end

    # Public: stop the application.
    #
    # Sends a SIGTERM to the app's process, and expects it to exit like a sane
    # and well-behaved application within 30 seconds before sending a SIGKILL.
    #
    # Uses config.kill_with for the initial signal, which defaults to "TERM".
    # If a configured process doesn't respond well to TERM (i.e. leaving
    # zombies), use KILL instead.
    def stop
      return unless @pid

      info "stopping #{@pid}"
      @master.close unless @master.closed?
      debug "kill -#{config.kill_with} #{@pid}"
      ::Process.kill config.kill_with, -@pid

      kill = after 30 do
        if @running
          warn "process #{@pid} did not shut down cleanly, killing it"
          debug "kill -KILL #{@pid}"
          ::Process.kill "KILL", -@pid
        end
      end

      wait :running # wait for the exit callback
      kill.cancel

    rescue Errno::ESRCH, Errno::EPERM
      exited
    end

    # Internal: callback for when the application port has opened
    def port_opened
      info "listening on #{config.host}:#{config.app_port}"
      signal :running, true
    end

    # Internal: callback for when the process has exited.
    def exited
      debug "pid #{@pid} has exited"
      info "exited."
      @running = false
      @pid = nil
      @wait_for_port.terminate if @wait_for_port.alive?
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
      in_clean_environment do
        in_clean_rbenv_environment do
          @pid = ::Process.spawn(
            config.env,
            %Q(bash -c "#{config.command}"),
            :in => slave,
            :out => slave,
            :err => slave,
            :chdir => config.dir,
            :pgroup => true
          )
        end
      end
      slave.close
      proxy_output @master
      debug "started with pid #{@pid}"

      @wait_for_exit = WaitForExit.new @pid, Actor.current
      @wait_for_port = WaitForPort.new config.host, config.app_port, Actor.current

      timer = after config.startup_timeout do
        warn "application startup took more than #{config.startup_timeout}"
        stop!
      end

      @running = wait :running

      @starting = false
      timer.cancel

      @running
    rescue Errno::ENOENT
      @starting = false
      @running = false
      false
    ensure
      unless @running
        warn "could not start `#{config.command}`"
      end
    end

    # Private: check if the app is already running outside ringleader
    def already_running?
      socket = TCPSocket.new config.host, config.app_port
      socket.close
      true
    rescue Errno::ECONNREFUSED
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

    # Private: execute rbenv in a clean environment (rbenv only)
    # preserve the old ENV vars before deleting them and reinsert
    # them after the block
    def in_clean_rbenv_environment(&block)
      original_env_vars = {}
      if config.command =~ /^rbenv.*/ # only run if command starts with rbenv
        original_env_vars = ENV.to_hash.inject({}) { |h,(k,v)| h[k]=v if RBENV_CLEAN_ENV_VARS.include?(k); h }
        RBENV_CLEAN_ENV_VARS.each { |var| ENV.delete(var)}
      end
      yield
      original_env_vars.each { |k,v| ENV[k] = v }
    end

    # Private: execute a command in a clean environment (bundler)
    def in_clean_environment(&block)
      if Object.const_defined?(:Bundler)
        ::Bundler.with_clean_env(&block)
      else
        yield
      end
    end

  end

end
