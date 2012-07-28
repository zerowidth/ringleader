module Ringleader
  class AppSerializer
    def initialize(app)
      @app = app
    end

    def to_json(*args)
      {
        "name" => @app.name,
        "enabled" => @app.enabled?,
        "running" => @app.running?
      }.to_json(*args)
    end
  end
end
