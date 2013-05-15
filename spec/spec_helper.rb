require 'simplecov'
SimpleCov.start do
  add_filter "/vendor/"
  add_filter '.gem/'
  add_filter "/spec/"
  add_filter "/public/"
  add_filter "/tasks/"
end

require File.join(File.dirname(__FILE__), '..', 'app.rb')

require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'
require 'database_cleaner'

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # If any spec is tagged with the following vals, then filter to only run that spec
  config.filter_run :focus => true

  # If no specific specs filtered, then run everything
  config.run_all_when_everything_filtered = true
end

# set test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

