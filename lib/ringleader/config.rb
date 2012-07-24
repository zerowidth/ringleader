module Ringleader
  class Config

    DEFAULT_IDLE_TIMEOUT = 1800
    DEFAULT_STARTUP_TIMEOUT = 30
    DEFAULT_HOSTNAME = "127.0.0.1"
    REQUIRED_KEYS = %w(dir command)

    def initialize(file)
      @config = YAML.load(File.read(file))
    end

    def apps
      unless @apps
        configs = @config.map do |name, options|
          options["name"] = name
          options["hostname"] ||= DEFAULT_HOSTNAME
          options["idle_timeout"] ||= DEFAULT_IDLE_TIMEOUT
          options["startup_timeout"] ||= DEFAULT_STARTUP_TIMEOUT
          validate name, options
          [name, OpenStruct.new(options)]
        end

        @apps = Hash[*configs.flatten]
      end
      @apps
    end

    # Private: validate that the options have all of the required keys
    def validate(name, options)
      REQUIRED_KEYS.each do |key|
        unless options.has_key?(key)
          raise "#{key} missing in #{name} config" 
        end
      end
      if (options.has_key?("app_port") && !options.has_key?("server_port")) ||
        (!options.has_key?("app_port") && options.has_key?("server_port"))
        raise "must provide both app_port and server_port or neither for #{name} config"
      end
    end
  end
end
