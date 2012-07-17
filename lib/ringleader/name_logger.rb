module Ringleader
  module NameLogger
    # Send a debug message
    def debug(string)
      super with_name(string)
    end

    # Send a info message
    def info(string)
      super with_name(string)
    end

    # Send a warning message
    def warn(string)
      super with_name(string)
    end

    # Send an error message
    def error(string)
      super with_name(string)
    end

    def with_name(string)
      colorized = config.name.color(config.color)
      "#{colorized} | #{string}"
    end

  end
end
