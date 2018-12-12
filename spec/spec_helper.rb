# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'database_cleaner'
require 'active_record'

SimpleCov.start do
  add_filter '/spec/'
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # DatabaseCleaner
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

# Set up in-memory database with test schema & load test models
ActiveRecord::Base.establish_connection(adapter: :sqlite3, database: ':memory:')
load File.dirname(__FILE__) + '/support/schema.rb'
require File.dirname(__FILE__) + '/support/models'
