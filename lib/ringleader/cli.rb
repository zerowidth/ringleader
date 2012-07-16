module Ringleader
  class CLI
    include Celluloid::Logger

    def run(argv)
      Celluloid.logger.level = ::Logger::ERROR

      opts = nil
      Trollop.with_standard_exception_handling parser do
        opts = parser.parse argv
      end

      die "must provide a filename" if argv.empty?
      die "could not find config file #{argv.first}" unless File.exist?(argv.first)

      puts opts.inspect

      set_log_level(opts.verbose ? "debug" : "info")

      config = Config.new argv.first
      start_app_server config
    end

    def set_log_level(level)
      Celluloid.logger.level = ::Logger.const_get(level.upcase)
    end

    def start_app_server(config)
      apps = config.apps.map do |name, app_config|
        app = App.new app_config
        AppProxy.new app, app_config
        app
      end

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
      port: 4000
      # idle timeout in seconds, defaults to 0. 0 means "never".
      idle_timeout: 6000
    other_app:
      [...]

OPTIONS
        banner

        opt "verbose", "log at debug level", :long => "--verbose", :short => "-v", :type => :boolean

      end
    end

  end
end
