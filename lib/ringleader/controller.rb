module Ringleader
  class Controller
    include Celluloid
    include Celluloid::Logger

    def initialize(configs)
      @apps = {}
      configs.each do |name, config|
        @apps[name] = App.new(config)
      end
    end

    def stop
      exit if @stopping # if ctrl-c called twice...
      @stopping = true
      info "shutting down..."
      @apps.values.map do |app|
        Thread.new { app.stop }
      end.map(&:join)
    end
  end
end
