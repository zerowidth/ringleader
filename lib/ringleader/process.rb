module Ringleader

  # Represents an instance of a configured application.
  class Process
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
    # and well-behaved application within 7 seconds before sending a SIGKILL.
    #
    # Uses config.kill_with for the initial signal, which defaults to "TERM".
    # If a configured process doesn't respond well to TERM (i.e. leaving
    # zombies), use KILL instead.
    def stop
      return unless @pid

      children = child_pids @pid

      info "stopping #{@pid}"
      debug "child pids: #{children.inspect}"

      @master.close unless @master.closed?

      debug "kill -#{config.kill_with} #{@pid}"
      ::Process.kill config.kill_with, -@pid

      failsafe = after 7 do
        warn "process #{@pid} did not shut down cleanly, killing it"
        debug "kill -KILL #{@pid}"
        ::Process.kill "KILL", -@pid
        reap_orphans children
      end

      wait :running # wait for the exit callback
      failsafe.cancel
      sleep 2 # give the children a chance to shut down
      reap_orphans children

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
      info "pid #{@pid} exited"
      @running = false
      @pid = nil
      @wait_for_port.terminate if @wait_for_port.alive?
      @wait_for_exit.terminate if @wait_for_exit.alive?
      signal :running, false
    end

    # Internal: start the application process and associated infrastructure
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
      slave.close
      proxy_output @master
      debug "started with pid #{@pid}"

      @wait_for_exit = WaitForExit.new @pid, Actor.current
      @wait_for_port = WaitForPort.new config.host, config.app_port, Actor.current

      timer = after config.startup_timeout do
        warn "application startup took more than #{config.startup_timeout}"
        async.stop
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

    # Internal: check if the app is already running outside ringleader
    def already_running?
      socket = TCPSocket.new config.host, config.app_port
      socket.close
      true
    rescue Errno::ECONNREFUSED
      false
    end

    # Internal: proxy output streams to the logger.
    #
    # Fire and forget, runs in its own thread.
    def proxy_output(input)
      Thread.new do
        until input.eof?
          info input.gets.strip
        end
      end
    end

    # Internal: execute a command in a clean environment (bundler)
    def in_clean_environment(&block)
      if Object.const_defined?(:Bundler)
        ::Bundler.with_clean_env(&block)
      else
        yield
      end
    end

    # Internal: kill orphaned processes
    def reap_orphans(child_pids)
      child_pids.each do |pid|
        next unless Sys::ProcTable.ps(pid)
        error "child process #{pid} was orphaned, killing it"
        begin
          ::Process.kill "KILL", pid
        rescue Errno::ESRCH, Errno::EPERM
          debug "could not kill #{pid}"
        end
      end
    end

    # Internal: returns all child pids of the given parent
    def child_pids(parent_pid)
      proc_table = Sys::ProcTable.ps
      children_of parent_pid, proc_table
    end

    # Internal: find child pids given a parent pid and a proc table
    def children_of(parent_pid, proc_table)
      [].tap do |pids|
        proc_table.each do |proc_record|
          if proc_record.ppid == parent_pid
            pids << proc_record.pid
            pids.concat children_of proc_record.pid, proc_table
          end
        end
      end
    end

  end

end
