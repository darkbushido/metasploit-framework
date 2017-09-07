require 'spec_helper'

RSpec.describe Msf::Framework do
  include_context 'Metasploit::Framework::Thread::Manager cleaner' do
    let(:thread_manager) do
      # don't create thread manager if example didn't create it
      framework.instance_variable_get :@threads
    end
  end

  subject(:framework) do
    described_class.new
  end

  it { expect(framework).to be_a MonitorMixin }

  context '#datastore' do
    subject(:datastore) do
      framework.datastore
    end

    it 'should use lazy initialization' do
      expect(Msf::DataStore).not_to receive(:new)

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      datastore
    end

    it 'should be memoized' do
      memoized = double('Msf::Datastore')
      framework.instance_variable_set :@datastore, memoized

      expect(datastore).to eql memoized
    end

    it { should be_a Msf::DataStore }
  end

  context '#db' do
    subject(:db) do
      framework.db
    end

    it 'should use lazy initialization' do
      expect(Msf::DBManager).not_to receive(:new)

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      db
    end

    it 'should be memoized' do
      memoized = double('Msf::Datastore')
      framework.instance_variable_set :@db, memoized

      expect(db).to eql memoized
    end

    it 'should pass framework to Msf::DBManager.new' do
      expect(Msf::DBManager).to receive(:new).with(framework, {}).and_call_original

      db
    end

    it { expect(db).to be_a Msf::DBManager }
  end

  context '#events' do
    subject(:events) do
      framework.events
    end

    it 'should be initialized in #initialize to allow event subscriptions #initialize' do
      expect(Msf::EventDispatcher).to receive(:new).and_call_original

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      events
    end

    it 'should be memoized' do
      memoized = double('Msf::Datastore')
      framework.instance_variable_set :@events, memoized

      expect(events).to eql memoized
    end

    it 'should pass framework to Msf::EventDispatcher.new' do
      # can't use with(framework) as it will trigger call before should_receive is setup
      expect(Msf::EventDispatcher).to receive(:new).with(
          an_instance_of(Msf::Framework)
      ).and_call_original

      framework
    end

    it { should be_a Msf::EventDispatcher }
  end

  context '#initialize' do
    subject(:framework) do
      described_class.new
    end

    it 'should set Rex::ThreadFactory.provider to #threads' do
      framework

      expect(Rex::ThreadFactory.class_variable_get(:@@provider)).to eql framework.threads
    end

    context 'events' do
      it 'should create an Msf::FrameworkEventSubscriber' do
        expect(Msf::FrameworkEventSubscriber).to receive(:new).with(
            an_instance_of(Msf::Framework)
        ).and_call_original

        framework
      end

      it 'should add exploit subscriber' do
        allow_any_instance_of(Msf::EventDispatcher).to receive(:add_exploit_subscriber)

        framework
      end

      it 'should add session subscriber' do
        allow_any_instance_of(Msf::EventDispatcher).to receive(:add_session_subscriber)

        framework
      end

      it 'should add general subscriber' do
        allow_any_instance_of(Msf::EventDispatcher).to receive(:add_general_subscriber)

        framework
      end

      it 'should add db subscriber' do
        allow_any_instance_of(Msf::EventDispatcher).to receive(:add_db_subscriber)

        framework
      end
    end
  end

  context '#jobs' do
    subject(:jobs) do
      framework.jobs
    end

    it 'should use lazy initialization' do
      expect(Rex::JobContainer).not_to receive(:new)

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      jobs
    end

    it 'should be memoized' do
      memoized = double('Rex::JobContainer')
      framework.instance_variable_set :@jobs, memoized

      expect(jobs).to eql memoized
    end

    it 'should pass framework to Rex::JobContainer.new' do
      expect(Rex::JobContainer).to receive(:new)

      jobs
    end

    it { should be_a Rex::JobContainer }
  end

  context '#plugins' do
    subject(:plugins) do
      framework.plugins
    end

    it 'should use lazy initialization' do
      expect(Msf::PluginManager).not_to receive(:new)

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      plugins
    end

    it 'should be memoized' do
      memoized = double('Msf::PluginManager')
      framework.instance_variable_set :@plugins, memoized
      expect(plugins).to eql memoized
    end

    it 'should pass framework to Msf::PluginManager.new' do
      expect(Msf::PluginManager).to receive(:new).with(framework)

      plugins
    end

    it { should be_a Msf::PluginManager }
  end

  context '#sessions' do
    subject(:sessions) do
      framework.sessions
    end

    it 'should use lazy initialization' do
      expect(Msf::SessionManager).not_to receive(:new)

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      sessions
    end

    it 'should be memoized' do
      memoized = double('Msf::SessionManager')
      framework.instance_variable_set :@sessions, memoized

      expect(sessions).to eql memoized
    end

    it 'should pass framework to Msf::SessionManager.new' do
      expect(sessions.framework).to eql framework
    end

    it { should be_a Msf::SessionManager }
  end

  context '#threads' do
    subject(:threads) do
      framework.threads
    end

    # TODO https://www.pivotaltracker.com/story/show/57432206
    it 'should be initialized in #initialize when Rex::ThreadFactory.provider is set' do
      expect(Metasploit::Framework::Thread::Manager).to receive(:new)

      framework
    end

    it 'should be synchronized' do
      expect(framework).to receive(:synchronize)

      threads
    end

    it 'should be memoized' do
      memoized = double('Metasploit::Framework::Thread::Manager')
      framework.instance_variable_set :@threads, memoized

      begin
        expect(threads).to eql memoized
      ensure
        # make sure @threads is nil so Metasploit::Framework::Thread::Manager cleaner doesn't try to call #list on
        # memoized.
        framework.instance_variable_set :@threads, nil
      end
    end

    it 'should pass framework to Metasploit::Framework::Thread::Manager.new' do
      expect(Metasploit::Framework::Thread::Manager).to receive(:new).with(
          hash_including(framework: framework)
      )
      framework.instance_variable_set :@threads, nil

      framework.threads
    end

    it { should be_a Metasploit::Framework::Thread::Manager }
  end
end
