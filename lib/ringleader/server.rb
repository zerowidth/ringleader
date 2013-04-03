module Ringleader
  class Server < Reel::Server
    include Celluloid::Logger

    ASSET_PATH = Pathname.new(File.expand_path("../../../assets", __FILE__))
    ACTIONS = %w(enable disable stop start restart).freeze

    def initialize(controller, host, port)
      debug "starting webserver on #{host}:#{port}"
      super host, port, &method(:on_connection)
      @controller = controller
      info "web control panel started on http://#{host}:#{port}"
    end

    def on_connection(connection)
      request = connection.request
      route request if request
    end

    # thanks to dcell explorer for this code
    def route(request)
      if request.url == "/"
        path = "index.html"
      else
        path = request.url[%r{^/([a-z0-9\.\-_]+(/[a-z0-9\.\-_]+)*)$}, 1]
      end

      if !path or path[".."]
        request.respond :not_found, "Not found"
        debug "404 #{path}"
        return
      end

      case request.method
      when "GET"
        if path == "apps"
          app_index request
        elsif path =~ %r(^apps/\w+)
          show_app path, request
        else
          static_file path, request
        end
      when "POST"
        update_app path, request
      else
        error "unknown #{request.method} request to #{request.url}"
      end
    end

    def app_index(request)
      json = @controller.apps.map { |app| app_as_json(app) }.to_json
      request.respond :ok, json
      debug "GET /apps: 200"
    end

    def static_file(path, request)
      filename = ASSET_PATH + path
      if filename.exist?
        mime_type = content_type_for filename.extname
        filename.open("r") do |file|
          request.respond :ok, {"Content-type" => mime_type}, file
        end
        debug "GET #{path}: 200"
      else
        request.respond :not_found, "Not found"
        debug "GET #{path}: 404"
      end
    end

    def show_app(uri, request)
      _, name, _ = uri.split("/")
      app = @controller.app name
      if app
        request.respond :ok, app_as_json(app).to_json
        debug "GET #{uri}: 200"
      else
        request.respond :not_found, "Not found"
        debug "GET #{uri}: 404"
      end
    end

    def update_app(uri, request)
      _, name, action = uri.split("/")
      app = @controller.app name
      if app && ACTIONS.include?(action)
        app.send action
        request.respond :ok, app_as_json(app).to_json
        debug "POST #{uri}: 200"
      else
        request.respond :not_found, "Not found"
        debug "POST #{uri}: 404"
      end
    end

    def app_as_json(app)
      AppSerializer.new(app)
    end

    def content_type_for(extname)
      case extname
      when ".html"
        "text/html"
      when ".js"
        "application/json"
      when ".css"
        "text/css"
      when ".ico"
        "image/x-icon"
      when ".png"
        "image/png"
      else
        "text/plain"
      end
    end

  end
end
