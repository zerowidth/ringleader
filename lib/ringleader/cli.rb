module Ringleader
  class CLI
    include Celluloid::Logger

    TERMINAL_COLORS = [:red, :green, :yellow, :blue, :magenta, :cyan]

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

      configs = Config.new(argv.first).apps.values
      colorized = assign_colors configs, opts.boring
      start_app_server colorized
    end

    def configure_logging(level)
      Celluloid.logger.level = ::Logger.const_get(level.upcase)
      format = "%5s %s.%06d | %s\n"
      date_format = "%H:%M:%S"
      Celluloid.logger.formatter = lambda do |severity, time, progname, msg|
        format % [severity, time.strftime(date_format), time.usec, msg]
      end
    end

    def assign_colors(configs, boring=false)
      if boring
        configs.map.with_index do |config, i|
          config.color = TERMINAL_COLORS[ i % TERMINAL_COLORS.length ]
          config
        end
      else
        offset = 360/configs.size
        configs.map.with_index do |config, i|
          config.color = Color::HSL.new(offset * i, 100, 50).html
          config
        end
      end
    end

    def start_app_server(app_configs)
      apps = app_configs.map do |app_config|
        app = App.new app_config
        if app.persistent?
          app.start!
        else
          AppProxy.new app, app_config
        end
        app
      end

      # gracefully die instead of showing an interrupted sleep below
      trap("INT") do
        info "shutting down..."
        apps.each { |app| app.stop! }
        exit
      end

      sleep
    end

    def die(msg)
      error msg
      exit -1
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
      # working directory, where to start the app from
      dir: "~/apps/main"
      # the command to run to start up the app server. Executed under "bash -c".
      command: "foreman start"
      # the host to listen on, defaults to 127.0.0.1
      hostname: 0.0.0.0
      # the port ringleader listens on
      server_port: 3000
      # the port the application listens on
      app_port: 4000
      # idle timeout in seconds, defaults to #{Config::DEFAULT_IDLE_TIMEOUT}. 0 means "never".
      idle_timeout: 6000
      # application startup timeout, defaults to #{Config::DEFAULT_STARTUP_TIMEOUT}.
      startup_timeout: 180
    other_app:
      [...]

OPTIONS
        banner

        opt "verbose", "log at debug level", :long => "--verbose", :short => "-v", :type => :boolean
        opt "boring", "use boring colors instead of a fabulous rainbow", :long => "--boring", :short => "-b", :type => :boolean, :default => false

      end
    end

  end
end
