module Ringleader
  class Config

    DEFAULT_IDLE_TIMEOUT = 1800
    DEFAULT_STARTUP_TIMEOUT = 30
    DEFAULT_HOST= "127.0.0.1"
    REQUIRED_KEYS = %w(dir command app_port server_port)

    TERMINAL_COLORS = [:red, :green, :yellow, :blue, :magenta, :cyan]

    attr_reader :apps

    # Public: Load the configs from a file
    #
    # file   - the yml file to load the config from
    # boring - use terminal colors instead of a rainbow for app colors
    def initialize(file, boring=false)
      config_data = YAML.load(File.read(file))
      configs = convert_and_validate config_data, boring
      @apps = Hash[*configs.flatten]
    end

    # Private: convert a YML hash to an array of name/OpenStruct pairs
    #
    # Does validation for each app config and raises an error if anything is
    # wrong. Sets default values for missing options, and assigns colors to each
    # app config.
    #
    # configs - a hash of config data
    # boring  - whether or not to use a rainbow of colors for the apps
    #
    # Returns [ [app_name, OpenStruct], ... ]
    def convert_and_validate(configs, boring)
      assign_colors configs, boring
      configs.map do |name, options|
        options["name"] = name
        options["host"] ||= DEFAULT_HOST
        options["idle_timeout"] ||= DEFAULT_IDLE_TIMEOUT
        options["startup_timeout"] ||= DEFAULT_STARTUP_TIMEOUT
        options["kill_with"] ||= "TERM"
        options["env"] ||= {}

        if command = options.delete("rvm")
          options["command"] = "source ~/.rvm/scripts/rvm && rvm --with-rubies rvmrc exec -- #{command}"
        elsif command = options.delete("rbenv")
          options["command"] = "rbenv exec #{command}"
          options["env"]["RBENV_VERSION"] = nil
          options["env"]["RBENV_DIR"] = nil
          options["env"]["GEM_HOME"] = nil
        end

        validate name, options

        options["dir"] = File.expand_path options["dir"]

        [name, OpenStruct.new(options)]
      end
    end

    # Private: validate that the options have all of the required keys
    def validate(name, options)
      REQUIRED_KEYS.each do |key|
        unless options.has_key?(key)
          raise "#{key} missing in #{name} config" 
        end
      end
    end

    # Private: assign a color to each application configuration.
    #
    # configs - the config data to modify
    # boring  - use boring standard terminal colors instead of a rainbow.
    def assign_colors(configs, boring)
      sorted = configs.sort_by(&:first).map(&:last)
      if boring
        sorted.each.with_index do |config, i|
          config["color"] = TERMINAL_COLORS[ i % TERMINAL_COLORS.length ]
        end
      else
        offset = 360/configs.size
        sorted.each.with_index do |config, i|
          config["color"] = Color::HSL.new(offset * i, 100, 50).html
        end
      end
    end

  end
end
