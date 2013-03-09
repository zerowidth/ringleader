module Ringleader
  class WaitForExit
    include Celluloid

    def initialize(pid, app)
      @pid, @app = pid, app
      async.wait
    end

    def wait
      ::Process.waitpid @pid
      @app.async.exited
      terminate
    end
  end
end
