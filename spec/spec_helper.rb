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

# Set up database with test schema & load test models
def active_record_connection_properties
  type = case ENV['PRUNE_AR_TEST_DATABASE_TYPE']
         when 'postgres'
           'postgres'
         else
           'sqlite3'
         end

  file = "#{File.dirname(__FILE__)}/support/database_configs/#{type}.yml"
  YAML.load_file(file).transform_keys(&:to_sym)
end

ActiveRecord::Base.establish_connection(**active_record_connection_properties)
load File.dirname(__FILE__) + '/support/schema.rb'
require File.dirname(__FILE__) + '/support/models'

def database_type
  ActiveRecord::Base.connection.adapter_name.downcase.to_sym
end

def foreign_keys_supported?
  %i[postgresql].include?(database_type)
end
