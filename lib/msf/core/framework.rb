# -*- coding: binary -*-

#
# Standard Library
#

require 'monitor'

#
# Project
#

require 'metasploit/framework/version'
require 'msf/base/config'
require 'msf/core'
require 'msf/util'

module Msf

###
#
# This class is the primary context that modules, scripts, and user
# interfaces interact with.  It ties everything together.
#
###
class Framework < Metasploit::Model::Base
  include MonitorMixin

  #
  # Versioning information
  #

  Major    = Metasploit::Framework::Version::MAJOR
  Minor    = Metasploit::Framework::Version::MINOR
  Point    = Metasploit::Framework::Version::PATCH
  Release  = "-#{Metasploit::Framework::Version::PRERELEASE}"
  Version  = Metasploit::Framework::VERSION

  Revision = "$Revision$"

  # EICAR canary
  EICARCorrupted      = ::Msf::Util::EXE.is_eicar_corrupted?

  #
  # Mixin meant to be included into all classes that can have instances that
  # should be tied to the framework, such as modules.
  #
  module Offspring

    #
    # A reference to the framework instance from which this offspring was
    # derived.
    #
    attr_accessor :framework
  end

  #
  # Attributes
  #

  # @!attribute [r] pathnames
  #   @note Pathnames is immutable and unchanging after {#initialize} returns, so it is safe to return a local copy
  #     in other threads and not worry about mutation.
  #
  #   Framework-specific pathnames for {Metasploit::Framework::Framework::Pathnames#file configuration file},
  #   {Metasploit::Framework::Framework::Pathnames#history msfconsole history}, etc.
  #
  #   @return [Metasploit::Framework::Framework::Pathnames]
  attr_reader :pathnames

  # @!attribute [rw] database_disabled
  #   Whether {#db} should be {Msf::DBManager#disabled}.
  #
  #   @return [Boolean] Defaults to `false`.


  #
  # Methods
  #

  def database_disabled
    @database_disabled ||= false
  end
  alias database_disabled? database_disabled
  attr_writer :database_disabled

  # Requires need to be here because they use Msf::Framework::Offspring, which is declared immediately before this.
  require 'metasploit/framework/thread'
  require 'metasploit/framework/thread/manager'
  require 'msf/core/db_manager'
  require 'msf/core/event_dispatcher'
  require 'rex/json_hash_file'

  # The global framework datastore that can be used by modules.
  #
  # @return [Msf::DataStore]
  # @todo https://www.pivotaltracker.com/story/show/57456210
  def datastore
    synchronize {
      @datastore ||= Msf::DataStore.new
    }
  end

  # Maintains the database and handles database events
  #
  # @return [Msf::DBManager]
  def db
    synchronize {
      @db ||= Msf::DBManager.new(self, options)
    }
  end

  # Event management interface for registering event handler subscribers and
  # for interacting with the correlation engine.
  #
  # @return [Msf::EventDispatcher]
  def events
    synchronize {
      @events ||= Msf::EventDispatcher.new(self)
    }
  end

  # Maintains the database and handles database events
  #
  def initialize(options={})
    self.options = options
    # call super to initialize MonitorMixin.  #synchronize won't work without this.
    super()

    # Allow specific module types to be loaded
    types = options[:module_types] || Msf::MODULE_TYPES

    self.modules   = ModuleManager.new(self,types)
    self.uuid_db   = Rex::JSONHashFile.new(::File.join(Msf::Config.config_directory, "payloads.json"))
    self.browser_profiles = Hash.new
    if $output_debug_info
      puts "Setting threads up"
    end
    # Configure the thread factory
    Rex::ThreadFactory.provider = self.threads

    subscriber = FrameworkEventSubscriber.new(self)
    events.add_exploit_subscriber(subscriber)
    events.add_session_subscriber(subscriber)
    events.add_general_subscriber(subscriber)
    events.add_db_subscriber(subscriber)
    events.add_ui_subscriber(subscriber)
  end

  # Background job management specific to things spawned from this instance
  # of the framework.
  #
  # @return [Rex::JobContainer]
  def jobs
    synchronize {
      @jobs ||= Rex::JobContainer.new
    }
  end

  # The plugin manager allows for the loading and unloading of plugins.
  #
  # @return [Msf::PluginManager]
  def plugins
    synchronize {
      @plugins ||= Msf::PluginManager.new(self)
    }
  end

  # Session manager that tracks sessions associated with this framework
  # instance over the course of their lifetime.
  #
  # @return []
  def sessions
    synchronize {
      @sessions ||= Msf::SessionManager.new(self)
    }
  end

  def inspect
    "#<Framework (#{sessions.length} sessions, #{jobs.length} jobs, #{plugins.length} plugins#{db.active ? ", #{db.driver} database active" : ""})>"
  end

  #
  # Returns the module set for encoders.
  #
  def encoders
    return modules.encoders
  end

  #
  # Returns the module set for exploits.
  #
  def exploits
    return modules.exploits
  end

  #
  # Returns the module set for nops
  #
  # @return [Rex::JobContainer]
  def jobs
    synchronize {
      # @todo https://www.pivotaltracker.com/story/show/57432316
      @jobs ||= Rex::JobContainer.new
    }
  end

  # The plugin manager allows for the loading and unloading of plugins.
  #
  # @return [Msf::PluginManager]
  def plugins
    synchronize {
      @plugins ||= Msf::PluginManager.new(self)
    }
  end

  # Session manager that tracks sessions associated with this framework
  # instance over the course of their lifetime.
  #
  # @return []
  def sessions
    synchronize {
      @sessions ||= Msf::SessionManager.new(self)
    }
  end

  # The thread manager provides a cleaner way to manage spawned threads.
  #
  # @return [Metasploit::Framework::Thread::Manager]
  def threads
    synchronize {
      @threads ||= Metasploit::Framework::Thread::Manager.new(framework: self)
    }
  end

  #
  # Returns the module set for encoders.
  #
  def encoders
    return modules.encoders
  end

  #
  # Returns the module set for exploits.
  #
  def exploits
    return modules.exploits
  end

  #
  # Returns the module set for nops
  #
  def nops
    return modules.nops
  end

  #
  # Returns the module set for payloads
  #
  def payloads
    return modules.payloads
  end

  #
  # Returns the module set for auxiliary modules
  #
  def auxiliary
    return modules.auxiliary
  end

  #
  # Returns the module set for post modules
  #
  def post
    return modules.post
  end

  #
  # Returns the framework version in Major.Minor format.
  #
  def version
    Version
  end

  #
  # Module manager that contains information about all loaded modules,
  # regardless of type.
  #
  attr_reader   :modules
  #
  # The framework instance's aux manager.  The aux manager is responsible
  # for collecting and cataloging all aux information that comes in from
  # aux modules.
  #
  attr_reader   :auxmgr
  #
  # The framework instance's payload uuid database.  The payload uuid
  # database is used to record and match the unique ID values embedded
  # into generated payloads.
  #
  attr_reader   :uuid_db
  #
  # The framework instance's browser profile store. These profiles are
  # generated by client-side modules and need to be shared across
  # different contexts.
  #
  attr_reader   :browser_profiles

  # Whether {#threads} has been initialized
  #
  # @return [true] if {#threads} has been initialized
  # @return [false] otherwise
  def threads?
    synchronize {
      instance_variable_defined? :@threads
    }
  end

  def search(match, logger: nil)
    # Check if the database is usable
    use_db = true
    if self.db
      if !(self.db.migrated && self.db.modules_cached)
        logger.print_warning("Module database cache not built yet, using slow search") if logger
        use_db = false
      end
    else
      logger.print_warning("Database not connected, using slow search") if logger
      use_db = false
    end

    # Used the database for search
    if use_db
      return self.db.search_modules(match)
    end

    # Do an in-place search
    matches = []
    [ self.exploits, self.auxiliary, self.post, self.payloads, self.nops, self.encoders ].each do |mset|
      mset.each do |m|
        begin
          o = mset.create(m[0])
          if o && !o.search_filter(match)
            matches << o
          end
        rescue
        end
      end
    end
    matches
  end

protected

  # @!attribute options
  #   Options passed to {#initialize}
  #
  #   @return [Hash]
  attr_accessor :options

  attr_writer   :modules # :nodoc:
  attr_writer   :auxmgr # :nodoc:
  attr_writer   :uuid_db # :nodoc:
  attr_writer   :browser_profiles # :nodoc:
end

class FrameworkEventSubscriber
  include Framework::Offspring
  def initialize(framework)
    self.framework = framework
  end

  def report_event(data)
    if framework.db.active
      framework.db.report_event(data)
    end
  end

  include GeneralEventSubscriber

  #
  # Generic handler for module events
  #
  def module_event(name, instance, opts={})
    if framework.db.active
      event = {
        :workspace => framework.db.find_workspace(instance.workspace),
        :name      => name,
        :username  => instance.owner,
        :info => {
          :module_name => instance.fullname,
          :module_uuid => instance.uuid
        }.merge(opts)
      }

      report_event(event)
    end
  end

  ##
  # :category: ::Msf::GeneralEventSubscriber implementors
  def on_module_run(instance)
    opts = { :datastore => instance.datastore.to_h }
    module_event('module_run', instance, opts)
  end

  ##
  # :category: ::Msf::GeneralEventSubscriber implementors
  def on_module_complete(instance)
    module_event('module_complete', instance)
  end

  ##
  # :category: ::Msf::GeneralEventSubscriber implementors
  def on_module_error(instance, exception=nil)
    module_event('module_error', instance, :exception => exception.to_s)
  end

  include ::Msf::UiEventSubscriber
  ##
  # :category: ::Msf::UiEventSubscriber implementors
  def on_ui_command(command)
    if framework.db.active
      report_event(:name => "ui_command", :info => {:command => command})
    end
  end

  ##
  # :category: ::Msf::UiEventSubscriber implementors
  def on_ui_stop()
    if framework.db.active
      report_event(:name => "ui_stop")
    end
  end

  ##
  # :category: ::Msf::UiEventSubscriber implementors
  def on_ui_start(rev)
    #
    # The database is not active at startup time unless msfconsole was
    # started with a database.yml, so this event won't always be saved to
    # the db.  Not great, but best we can do.
    #
    info = { :revision => rev }
    report_event(:name => "ui_start", :info => info)
  end

  require 'msf/core/session'

  include ::Msf::SessionEvent

  #
  # Generic handler for session events
  #
  def session_event(name, session, opts={})
    address = session.session_host

    if not (address and address.length > 0)
      elog("Session with no session_host/target_host/tunnel_peer")
      dlog("#{session.inspect}", LEV_3)
      return
    end

    if framework.db.active
      ws = framework.db.find_workspace(session.workspace)
      event = {
        :workspace => ws,
        :username  => session.username,
        :name => name,
        :host => address,
        :info => {
          :session_id   => session.sid,
          :session_info => session.info,
          :session_uuid => session.uuid,
          :session_type => session.type,
          :username     => session.username,
          :target_host  => address,
          :via_exploit  => session.via_exploit,
          :via_payload  => session.via_payload,
          :tunnel_peer  => session.tunnel_peer,
          :exploit_uuid => session.exploit_uuid
        }.merge(opts)
      }
      report_event(event)
    end
  end


  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_open(session)
    opts = { :datastore => session.exploit_datastore.to_h, :critical => true }
    session_event('session_open', session, opts)
    framework.db.report_session(:session => session)
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_upload(session, lpath, rpath)
    session_event('session_upload', session, :local_path => lpath, :remote_path => rpath)
    framework.db.report_session_event({
      :etype => 'upload',
      :session => session,
      :local_path => lpath,
      :remote_path => rpath
    })
  end
  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_download(session, rpath, lpath)
    session_event('session_download', session, :local_path => lpath, :remote_path => rpath)
    framework.db.report_session_event({
      :etype => 'download',
      :session => session,
      :local_path => lpath,
      :remote_path => rpath
    })
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_close(session, reason='')
    session_event('session_close', session)
    if session.db_record
      # Don't bother saving here, the session's cleanup method will take
      # care of that later.
      session.db_record.close_reason = reason
      session.db_record.closed_at = Time.now.utc
    end
  end

  #def on_session_interact(session)
  #	$stdout.puts('session_interact', session.inspect)
  #end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_command(session, command)
    session_event('session_command', session, :command => command)
    framework.db.report_session_event({
      :etype => 'command',
      :session => session,
      :command => command
    })
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_output(session, output)
    # Break up the output into chunks that will fit into the database.
    buff = output.dup
    chunks = []
    if buff.length > 1024
      while buff.length > 0
        chunks << buff.slice!(0,1024)
      end
    else
      chunks << buff
    end
    chunks.each { |chunk|
      session_event('session_output', session, :output => chunk)
      framework.db.report_session_event({
        :etype => 'output',
        :session => session,
        :output => chunk
      })
    }
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_route(session, route)
    framework.db.report_session_route(session, route)
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_route_remove(session, route)
    framework.db.report_session_route_remove(session, route)
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_script_run(session, script)
    framework.db.report_session_event({
      :etype => 'script_run',
      :session => session,
      :local_path => script
    })
  end

  ##
  # :category: ::Msf::SessionEvent implementors
  def on_session_module_run(session, mod)
    framework.db.report_session_event({
      :etype => 'module_run',
      :session => session,
      :local_path => mod.fullname
    })
  end

  #
  # This is covered by on_module_run and on_session_open, so don't bother
  #
  #require 'msf/core/exploit'
  #include ExploitEvent
  #def on_exploit_success(exploit, session)
  #end

end
end
