require "ringleader"
server = Ringleader::Server.new "0.0.0.0", 42000
trap(:INT) { server.terminate; exit }
sleep
