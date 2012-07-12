require "rubygems"
require "celluloid/io"

class App
  include Celluloid
  include Celluloid::Logger

  def initialize(cmd)
    @cmd = cmd
    run!
  end

  def run
    reader, writer = ::IO.pipe
    @pid = Process.spawn @cmd, :out => writer, :err => writer
    info "started process: #{@pid}"
    proxy reader, $stdout
  end

  def proxy(input, output)
    Thread.new do
      until input.eof?
        info "#{@pid} | " + input.gets.strip
      end
    end
  end

  def stop
    info "stopping #{@cmd}"
    Process.kill("SIGHUP", @pid)
    info "waiting for #{@cmd}"
    status = Process.wait @pid
  rescue Errno::ESRCH, Errno::EPERM
  ensure
    terminate
  end

end

app = App.new "bundle exec foreman start"
# app = App.new "ruby sleep_loop.rb 5"

trap("INT") do
  app.stop
  exit
end
sleep
