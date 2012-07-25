module Ringleader
  class Server < Reel::Server
    include Celluloid::IO # hurk
    include Celluloid::Logger

    ASSET_PATH = Pathname.new(File.expand_path("../../../public", __FILE__))

    def initialize(host="localhost", port="4200")
      debug "starting webserver on #{host}:#{port}"
      super host, port, &method(:on_connection)
    end

    def on_connection(connection)
      request = connection.request
      route connection, request if request
    end

    def route(connection, request)
      static_file request.url, connection
    end

    def static_file(uri, connection)
      uri = "/index.html" if uri == "/"
      filename = ASSET_PATH + File.basename(uri)
      if filename.exist?
        debug "GET #{uri}: 200"
        filename.open("r") do |file|
          connection.respond :ok, file
        end
      else
        debug "GET #{uri}: 404"
        connection.respond :not_found, "Not found"
      end
    end

  end
end
