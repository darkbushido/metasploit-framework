#
# Gems
#

require 'active_support/core_ext/module/introspection'

#
# Project
#

require 'metasploit/framework/command'
require 'metasploit/framework/parsed_options'
require 'metasploit/framework/require'

# Based on pattern used for lib/rails/commands in the railties gem.
class Metasploit::Framework::Command::Console

  #
  # Attributes
  #

  # @!attribute [r] application
  #   The Rails application for metasploit-framework.
  #
  #   @return [Metasploit::Framework::Application]
  attr_reader :application

  # @!attribute [r] parsed_options
  #   The parsed options from the command line.
  #
  #   @return (see parsed_options)
  attr_reader :parsed_options
  
  #
  # Class Methods
  #

  # @note {require_environment!} should be called to load
  #   `config/application.rb` to so that the RAILS_ENV can be set from the
  #   command line options in `ARGV` prior to `Rails.env` being set.
  # @note After returning, `Rails.application` will be defined and configured.
  #
  # Parses `ARGV` for command line arguments to configure the
  # `Rails.application`.
  #
  # @return (see parsed_options)
  def self.require_environment!
    parsed_options = self.parsed_options
    # RAILS_ENV must be set before requiring 'config/application.rb'
    parsed_options.environment!
    ARGV.replace(parsed_options.positional)

    # allow other Rails::Applications to use this command
    if !defined?(Rails) || Rails.application.nil?
      # @see https://github.com/rails/rails/blob/v3.2.17/railties/lib/rails/commands.rb#L39-L40
      require Pathname.new(__FILE__).parent.parent.parent.parent.parent.join('config', 'application')
    end

    # have to configure before requiring environment because
    # config/environment.rb calls initialize! and the initializers will use
    # the configuration from the parsed options.
    parsed_options.configure(Rails.application)

    Rails.application.require_environment!

    parsed_options
  end

  def self.parsed_options
    parsed_options_class.new
  end

  def self.parsed_options_class
    @parsed_options_class ||= parsed_options_class_name.constantize
  end

  def self.parsed_options_class_name
    @parsed_options_class_name ||= "#{parent.parent}::ParsedOptions::#{name.demodulize}"
  end

  def self.start
    parsed_options = require_environment!
    new(application: Rails.application, parsed_options: parsed_options).start
  end

  #
  # Instance Methods
  #

  # @param attributes [Hash{Symbol => ActiveSupport::OrderedOptions,Rails::Application}]
  # @option attributes [Rails::Application] :application
  # @option attributes [ActiveSupport::OrderedOptions] :parsed_options
  # @raise [KeyError] if :application is not given
  # @raise [KeyError] if :parsed_options is not given
  def initialize(attributes={})
    @application = attributes.fetch(:application)
    @parsed_options = attributes.fetch(:parsed_options)
  end
  
  # Provides an animated spinner in a seperate thread.
  #
  # See GitHub issue #4147, as this may be blocking some
  # Windows instances, which is why Windows platforms
  # should simply return immediately.

  def spinner
    return if Rex::Compat.is_windows
    return if Rex::Compat.is_cygwin
    return if $msf_spinner_thread
    $msf_spinner_thread = Thread.new do
      base_line = "[*] Starting the Metasploit Framework console..."
      cycle = 0
      loop do
        %q{/-\|}.each_char do |c|
          status = "#{base_line}#{c}\r"
          cycle += 1
          off    = cycle % base_line.length
          case status[off, 1]
          when /[a-z]/
            status[off, 1] = status[off, 1].upcase
          when /[A-Z]/
            status[off, 1] = status[off, 1].downcase
          end
          $stderr.print status
          ::IO.select(nil, nil, nil, 0.10)
        end
      end
    end
  end

  def start
    case parsed_options.options.subcommand
    when :version
      $stderr.puts "Framework Version: #{Metasploit::Framework::VERSION}"
    else
      spinner unless parsed_options.options.console.quiet
      driver.run
    end
  end

  private

  # The console UI driver.
  #
  # @return [Msf::Ui::Console::Driver]
  def driver
    unless @driver
      # require here so minimum loading is done before {start} is called.
      require 'msf/ui'

      @driver = Msf::Ui::Console::Driver.new(
          Msf::Ui::Console::Driver::DefaultPrompt,
          Msf::Ui::Console::Driver::DefaultPromptChar,
          driver_options
      )
    end

    @driver
  end

  def driver_options
    unless @driver_options
      options = parsed_options.options

      driver_options = {}
      driver_options['Config'] = options.framework.config
      driver_options['ConfirmExit'] = options.console.confirm_exit
      driver_options['DatabaseEnv'] = options.environment
      driver_options['DatabaseMigrationPaths'] = options.database.migrations_paths
      driver_options['DatabaseYAML'] = options.database.config
      driver_options['DeferModuleLoads'] = options.modules.defer_loads
      driver_options['DisableBanner'] = options.console.quiet
      driver_options['DisableDatabase'] = options.database.disable
      driver_options['LocalOutput'] = options.console.local_output
      driver_options['ModulePath'] = options.modules.path
      driver_options['Plugins'] = options.console.plugins
      driver_options['RealReadline'] = options.console.real_readline
      driver_options['Resource'] = options.console.resources
      driver_options['XCommands'] = options.console.commands

      @driver_options = driver_options
    end

    @driver_options
  end
end
