module Ringleader
  class Server < Reel::Server
    include Celluloid::IO # hurk
    include Celluloid::Logger

    ASSET_PATH = Pathname.new(File.expand_path("../../../public", __FILE__))

    def initialize(apps, host="localhost", port=42000)
      debug "starting webserver on #{host}:#{port}"
      super host, port, &method(:on_connection)
      @apps = apps
    end

    def on_connection(connection)
      request = connection.request
      route connection, request if request
    end

    # thanks to dcell explorer for this code
    def route(connection, request)
      if request.url == "/"
        path = "index.html"
      else
        path = request.url[%r{^/([a-z0-9\.\-_]+(/[a-z0-9\.\-_]+)*)$}, 1]
      end

      if !path or path[".."]
        connection.respond :not_found, "Not found"
        return
      end

      case request.method
      when :get
        if path == "/apps.json"
          app_index connection
        else
          static_file path, connection
        end
      when :put
        update_app path, request.body, connection
      end
    end

    def app_index(connection)
      connection.respond :ok, "{}"
    end

    def static_file(path, connection)
      filename = ASSET_PATH + path
      if filename.exist?
        debug "GET #{path}: 200"
        mime_type = content_type_for filename.extname
        filename.open("r") do |file|
          connection.respond :ok, {"Content-type" => mime_type}, file
        end
      else
        debug "GET #{path}: 404"
        connection.respond :not_found, "Not found"
      end
    end

    def update_app(uri, body, connection)
    end

    def content_type_for(extname)
      case extname
      when ".html"
        "text/html"
      when ".js"
        "application/json"
      when ".css"
        "text/css"
      else
        "text/plain"
      end
    end

  end
end
