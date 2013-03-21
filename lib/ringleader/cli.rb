module Ringleader
  class CLI
    include Celluloid::Logger

    RC_FILE = File.expand_path('~/.ringleaderrc')

    def run(argv)
      configure_logging

      opts = nil
      Trollop.with_standard_exception_handling parser do
        raise Trollop::HelpNeeded if argv.empty?
        opts = merge_rc_opts(parser.parse(argv))
      end

      die "could not find config file #{argv.first}" unless File.exist?(argv.first)

      if opts.verbose?
        Celluloid.logger.level = ::Logger::DEBUG
      end

      apps = Config.new(argv.first, opts.boring).apps

      controller = Controller.new(apps)
      Server.new(controller, opts.host, opts.port)

      # gracefully die instead of showing an interrupted sleep below
      trap("INT") do
        controller.stop
        exit
      end

      sleep
    end

    def configure_logging
      # set to INFO at first to hide celluloid's shutdown message until after
      # opts are validated.
      Celluloid.logger.level = ::Logger::INFO
      format = "%5s %s.%06d | %s\n"
      date_format = "%H:%M:%S"
      Celluloid.logger.formatter = lambda do |severity, time, progname, msg|
        format % [severity, time.strftime(date_format), time.usec, msg]
      end
    end

    def die(msg)
      error msg
      exit(-1)
    end

    def parser
      @parser ||= Trollop::Parser.new do

        version Ringleader::VERSION

        banner <<-banner
ringleader - your socket app server host

SYNOPSIS

Ringleader runs, monitors, and proxies socket applications. Upon receiving a new
connection to a given port, ringleader will start the correct application and
proxy the connection to the now-running app. It also supports automatic timeout
for shutting down applications that haven't been used recently.

USAGE

    ringleader <config.yml> [options+]

APPLICATIONS

Ringleader supports any application that runs in the foreground (not
daemonized), and listens on a port. It expects applications to be well-behaved,
that is, respond appropriately to SIGINT for graceful shutdown.

When first starting an app, ringleader will wait for the application's port to
open, at which point it will proxy the incoming connection through.

SIGNALS

While ringleader is running, Ctrl+C (SIGINT) will gracefully shut down
ringleader as well as the applications it's hosting.

CONFIGURATION

Ringleader requires a configuration .yml file to operate. The file should look
something like this:

    ---
    # name of app (used in logging)
    main_app:

      # Required settings
      dir: "~/apps/main"       # Working directory
      command: "foreman start" # The command to run to start up the app server.
                               # Executed under "bash -c".
      server_port: 3000        # The port ringleader listens on
      app_port: 4000           # The port the application listens on

      # Optional settings
      host: 127.0.0.1          # The host ringleader should listen on
      idle_timeout: 6000       # Idle timeout in seconds, 0 for infinite
      startup_timeout: 180     # Application startup timeout
      disabled: true           # Set the app to be disabled when ringleader starts
      env:                     # Override or set environment variables inherited
        FOO: hello             # from the current environment. Use nil to unset a
        BAR: nil               # var.
      kill_with: INT           # Signal to use to kill the process tree with. Use
                               # TERM or KILL if the default is leaving zombies.
      run_on_load: false       # Set this to true to start an app when ringleader
                               # loads.

      # If you have an application managed by rvm, this setting automatically
      # adds the rvm-specific shell setup before executing the given command.
      # This supersedes the `command` setting.
      rvm: "foreman start"

      # Likewise for rbenv:
      rbenv: "foreman start"

OPTIONS
        banner

        opt :verbose, "log at debug level",
          :short => "-v", :default => false
        opt :host, "host for web control panel",
          :short => "-H", :default => "localhost"
        opt :port, "port for the web control panel",
          :short => "-p", :default => 42000
        opt :boring, "use boring colors instead of a fabulous rainbow",
          :short => "-b", :default => false

      end
    end

    def merge_rc_opts(opts)
      [:verbose, :host, :port, :boring].each do |option_name|
        if rc_opts.has_key?(option_name) && !opts["#{option_name}_given".to_sym]
          opts[option_name] = rc_opts[option_name]
        end
      end
      opts
    end

    def rc_opts
      unless @rc_opts
        if File.readable?(RC_FILE)
          info "reading options from ~/.ringleaderrc"
          @rc_opts = parser.parse File.read(RC_FILE).strip.split(/\s+/)
        else
          @rc_opts = {}
        end
      end
      @rc_opts
    end

  end
end
