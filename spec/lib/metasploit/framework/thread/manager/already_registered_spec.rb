require 'spec_helper'

RSpec.describe Metasploit::Framework::Thread::Manager::AlreadyRegistered do
  subject(:already_registered) do
    described_class.new(metasploit_framework_thread)
  end

  let(:metasploit_framework_thread) do
    FactoryGirl.create(:metasploit_framework_thread)
  end

  it { should be_a Metasploit::Framework::Error }

  context '#message' do
    subject(:message) do
      already_registered.message
    end

    it 'should include metasploit_framework_thread.inspect' do
      expect(message).to include(metasploit_framework_thread.inspect)
    end
  end

  context '#metasploit_framework_thread' do
    subject(:actual_metasploit_framework_thread) do
      already_registered.metasploit_framework_thread
    end

    it 'should be Metasploit::Framework::Thread passed to #new' do
      expect(actual_metasploit_framework_thread).to eql metasploit_framework_thread
    end
  end
end
