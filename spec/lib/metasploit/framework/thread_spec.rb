require 'spec_helper'

RSpec.describe Metasploit::Framework::Thread, type: :model do
  subject(:thread) do
    FactoryGirl.create(:metasploit_framework_thread)
  end

  let(:error) do
    Exception.new(message)
  end

  let(:message) do
    'Error Message'
  end

  context 'factories' do
    context 'metasploit_framework_thread' do
      subject(:metasploit_framework_thread) do
        FactoryGirl.build(:metasploit_framework_thread)
      end

      it { is_expected.to be_valid }

      it { expect(thread.critical).to be false }
    end
  end

  context 'validations' do
    it { is_expected.to validate_presence_of :backtrace }
    it { is_expected.to validate_presence_of :block }
    it { is_expected.to validate_presence_of(:critical).with_message("is not included in the list") }
    it { is_expected.to validate_presence_of :name }
  end

  context '#as_json' do
    subject(:as_json) do
      thread.as_json
    end

    context '[:backtrace]' do
      subject(:json_backtrace) do
        as_json[:backtrace]
      end

      it 'should be #backtrace' do
        expect(json_backtrace).to eql thread.backtrace
      end

      it 'should utf-8 encode each line in #backtrace' do
        thread.backtrace.each do |line|
          expect(line).to receive(:encode).with('utf-8')
        end

        as_json
      end
    end

    context '[:critical]' do
      subject(:json_critical) do
        as_json[:critical]
      end

      it 'should be #critical' do
        expect(json_critical).to eql thread.critical
      end
    end

    context '[:name]' do
      subject(:json_name) do
        as_json[:name]
      end

      it 'should be #name' do
        expect(json_name).to eql thread.name
      end

      it 'should encode #name in utf-8' do
        expect(thread.name).to receive(:encode).with('utf-8')

        as_json
      end
    end
  end

  context '#error_as_json' do
    subject(:error_as_json) do
      thread.send(:error_as_json, error)
    end

    context '[:backtrace]' do
      subject(:json_backtrace) do
        error_as_json[:backtrace]
      end

      context 'with Exception#backtrace' do
        let(:backtrace) do
          caller
        end

        before(:each) do
          error.set_backtrace(backtrace)
        end

        it 'should be error.backtrace' do
          expect(json_backtrace).to eql backtrace
        end
      end

      context 'without Exception#backtrace' do
        it { should be_nil }
      end
    end

    context '[:class]' do
      subject(:json_class) do
        error_as_json[:class]
      end

      it 'should be error.class.name' do
        expect(json_class).to eql error.class.name
      end
    end

    context '[:message]' do
      subject(:json_message) do
        error_as_json[:message]
      end

      it 'should be error message' do
        expect(json_message).to eql error.to_s
      end

      it 'should convert the error message to utf-8' do
        error_message = double('Error message')
        expect(error_message).to receive(:encode).with('utf-8')
        expect(error).to receive(:to_s) { error_message }

        json_message
      end
    end
  end

  context '#format_error_log_message' do
    subject(:format_error_log_message) do
      thread.send(:format_error_log_message, error)
    end

    it 'should use thread as JSON' do
      expect(thread).to receive(:as_json).and_return({})

      format_error_log_message
    end

    it 'should use error as JSON' do
      expect(thread).to receive(:error_as_json).with(error).and_return({})

      format_error_log_message
    end

    it 'should use thread as root key' do
      expect(format_error_log_message).to start_with("---\n:thread:\n")
    end
  end

  context '#initialize' do
    context 'with &block' do
      let(:block_block) do
        ->(*args) { args }
      end

      context 'with :block' do
        subject(:thread) do
          described_class.new(block: option_block, &block_block)
        end

        let(:option_block) do
          ->(*args) { args }
        end

        it 'should raise ArgumentError' do
          expect {
            thread
          }.to raise_error(ArgumentError)
        end

        it 'should not log error' do
          expect_any_instance_of(described_class).to_not receive(:elog)

          expect {
            thread
          }.to raise_error(ArgumentError)
        end
      end

      context 'without :block' do
        subject(:thread) {
          described_class.new(&block_block)
        }

        it 'should set #block to &block' do
          expect(thread.block).to eql block_block
        end
      end
    end
  end

  context '#log_and_raise' do
    subject(:log_and_raise) do
      thread.log_and_raise(error)
    end

    let(:error) do
      Exception.new("Metasploit::Framework::Thread#raise error")
    end

    it 'should use #format_error_log_message to produce argument to elog' do
      formatted = double('Formatted')
      expect(thread).to receive(:format_error_log_message).with(error).and_return(formatted)
      expect(thread).to receive(:elog).with(formatted)

      expect {
        log_and_raise
      }.to raise_error(error)
    end

    it 'should log error' do
      expect(thread).to receive(:elog)

      expect {
        log_and_raise
      }.to raise_error(error)
    end

    it 'should raise error' do
      expect {
        log_and_raise
      }.to raise_error(error)
    end
  end

  context '#run' do
    subject(:run) do
      thread.run
    end

    let(:block) do
      ->(*args) { args }
    end

    let(:block_arguments) do
      [
          :a,
          :b
      ]
    end

    let(:thread) do
      FactoryGirl.create(
          :metasploit_framework_thread,
          block: block,
          block_arguments: block_arguments
      )
    end

    it 'should pass *block_arguments to block' do
      expect(run).to eql block_arguments
    end
  end
end
