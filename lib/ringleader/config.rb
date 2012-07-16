module Ringleader
  class Config

    DEFAULT_IDLE_TIMEOUT = 0
    DEFAULT_HOSTNAME = "127.0.0.1"
    REQUIRED_KEYS = %w(dir command server_port port idle_timeout)

    def initialize(file)
      @config = YAML.load(File.read(file))
    end

    def apps
      configs = @config.map do |name, options|
        options["name"] = name
        options["hostname"] ||= DEFAULT_HOSTNAME
        options["idle_timeout"] ||= DEFAULT_IDLE_TIMEOUT
        validate name, options
        [name, OpenStruct.new(options)]
      end

      Hash[*configs.flatten]
    end

    # Private: validate that the options have all of the required keys
    def validate(name, options)
      REQUIRED_KEYS.each do |key|
        unless options.has_key?(key)
          raise "#{key} missing in #{name} config" 
        end
      end
    end
  end
end
