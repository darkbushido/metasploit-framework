#!/usr/bin/env rake
require File.expand_path('../config/application', __FILE__)
require 'metasploit/framework/require'
require 'metasploit/framework/spec/untested_payloads'

# `db:test:prepare` was depricated in rails 4.1, we are overridding it somewhere
# Rspec changed to detecting if `test:prepare` is defined.
# defining the task hear is a smaller change then fixing it the 'right' way.
task 'test:prepare' => 'db:test:prepare'

# @note must be before `Metasploit::Framework::Application.load_tasks`
#
# define db rake tasks from activerecord if activerecord is in the bundle.  activerecord could be not in the bundle if
# the user installs with `bundle install --without db`
Metasploit::Framework::Require.optionally_active_record_railtie

Metasploit::Framework::Application.load_tasks
Metasploit::Framework::Spec::Constants.define_task
Metasploit::Framework::Spec::Threads::Suite.define_task
Metasploit::Framework::Spec::UntestedPayloads.define_task
