require "proxy_server"

class AppProxy < ProxyServer
  include Celluloid::IO

  def initialize(host, port, dest_port, app)
    super host, port, dest_port
    @app = app
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr
    debug "received connection from #{host}:#{port}"

    started = @app.start
    if started
      proxy_to_app socket
    else
      error "could not start app"
      socket.close
    end
  end

  def proxy_to_app(socket)
    proxy = SocketProxy.new socket, @host, @dest_port
    debug "got proxy: #{proxy.inspect}"
    if proxy.alive?
      debug "proxy connected, hooray!"
    else
      debug "proxy isn't connected. sad times."
    end
  end
end

class App
  include Celluloid
  include Celluloid::Logger

  class Status
    def initialize(running)
      @running = running
    end
    def running?
      @running
    end
  end

  def initialize(cmd, port)
    @cmd = cmd
    @port = port
    @running = false
  end

  def start
    exclusive do
      if @running
        debug "already running: #{@cmd}"
        return true
      end

      debug "starting process: #{@cmd}"
      reader, writer = ::IO.pipe
      @pid = Process.spawn @cmd, :out => writer, :err => writer
      proxy reader
      debug "started with pid #{@pid}"

      @wait_for_exit = WaitForExit.new @pid, Actor.current
      @wait_for_port = WaitForPort.new "localhost", @port, Actor.current

      status = receive { |m| m.is_a? Status }
      @running = status.running?
    end
  rescue Errno::ENOENT
    debug "could not start process: #{@cmd}"
    false
  end

  def stop
    info "stopping #{@cmd}"
    Process.kill("SIGHUP", @pid)
  rescue Errno::ESRCH, Errno::EPERM
    stopped
  end

  def stopped
    info "process has gone away!"
    @running = false
    @wait_for_port.terminate if @wait_for_port.alive?
    @wait_for_exit.terminate if @wait_for_exit.alive?
  end

  def running?
    @running
  end

  def proxy(input)
    Thread.new do
      until input.eof?
        info "#{@pid} | " + input.gets.strip
      end
    end
  end
end

class WaitForExit
  include Celluloid

  def initialize(pid, app)
    @pid, @app = pid, app
    wait!
  end

  def wait
    Process.wait @pid
    @app.mailbox << App::Status.new(false)
    @app.stopped!
    terminate
  end
end

class WaitForPort
  include Celluloid
  include Celluloid::Logger

  def initialize(host, port, app)
    @host, @port, @app = host, port, app
    wait!
  end

  def wait
    debug "waiting for socket to open"
    begin
      socket = TCPSocket.new @host, @port
    rescue Errno::ECONNREFUSED
      sleep 0.5
      retry
    end
    debug "socket opened!"
    @app.mailbox << App::Status.new(true)
    terminate
  end
end

app = App.new("bundle exec foreman start", 10001)
# app = App.new("ls", 10001)
# puts "==> #{app.start}"
server = AppProxy.new "localhost", 10000, 10001, app
sleep
