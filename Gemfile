source 'https://rubygems.org'
# Add default group gems to `metasploit-framework.gemspec`:
#   spec.add_runtime_dependency '<name>', [<version requirements>]
gemspec name: 'metasploit-framework'
gem 'metasploit_data_models', github: 'rapid7/metasploit_data_models', branch: 'remove-recog-triggers'

gem 'time_difference'
gem 'awesome_print'
gem 'ruby-progressbar'
gem 'stackprof'
gem 'method_profiler'

# separate from test as simplecov is not run on travis-ci
group :coverage do
  # code coverage for tests
  gem 'simplecov'
end

group :development do
  # Markdown formatting for yard
  gem 'redcarpet'
  # generating documentation
  gem 'yard'
  # for development and testing purposes
  gem 'pry'
  # module documentation
  gem 'octokit'
  # Metasploit::Aggregator external session proxy
  # Disabled for now for crypttlv updates
  # gem 'metasploit-aggregator'
end

group :development, :test do
  # automatically include factories from spec/factories
  gem 'factory_girl_rails'
  # Make rspec output shorter and more useful
  gem 'fivemat'
  # running documentation generation tasks and rspec tasks
  gem 'rake'
  # Define `rake spec`.  Must be in development AND test so that its available by default as a rake test when the
  # environment is development
  gem 'rspec-rails'
  gem 'rspec-rerun'
end

group :test do
  # Manipulate Time.now in specs
  gem 'timecop'
end
