module Ringleader
  class WaitForExit
    include Celluloid

    def initialize(pid, app)
      @pid, @app = pid, app
      wait!
    end

    def wait
      ::Process.waitpid @pid
      @app.exited!
      terminate
    end
  end
end
