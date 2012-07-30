module Ringleader
  class CLI
    include Celluloid::Logger

    def run(argv)
      # hide "shutdown" info message until after opts are validated
      Celluloid.logger.level = ::Logger::ERROR

      opts = nil
      Trollop.with_standard_exception_handling parser do
        opts = parser.parse argv
      end

      die "must provide a filename" if argv.empty?
      die "could not find config file #{argv.first}" unless File.exist?(argv.first)

      configure_logging(opts.verbose ? "debug" : "info")

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

    def configure_logging(level)
      Celluloid.logger.level = ::Logger.const_get(level.upcase)
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
that is, respond appropriately to SIGHUP for graceful shutdown.

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
      idle_timeout: 6000       # Idle timeout in seconds
      startup_timeout: 180     # Application startup timeout
      disabled: true           # Set the app to be disabled when ringleader starts

      # If you have an application managed by rvm, this setting automatically
      # adds the rvm-specific shell setup before executing the given command.
      # This supersedes the `command` setting.
      rvm: "foreman start"

OPTIONS
        banner

        opt "verbose", "log at debug level",
          :long => "--verbose", :short => "-v",
          :type => :boolean, :default => false
        opt "host", "host for web control panel",
          :long => "--host", :short => "-H",
          :default => "localhost"
        opt "port", "port for the web control panel",
          :long => "--port", :short => "-p",
          :type => :integer, :default => 42000
        opt "boring", "use boring colors instead of a fabulous rainbow",
          :long => "--boring", :short => "-b",
          :type => :boolean, :default => false

      end
    end

  end
end
