# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'database_cleaner'
require 'active_record'

def active_record_connection_properties
  type = case ENV['PRUNE_AR_TEST_DATABASE_TYPE']
         when 'postgres'
           'postgres'
         when 'mysql'
           'mysql'
         else
           'sqlite3'
         end

  file = "#{File.dirname(__FILE__)}/support/database_configs/#{type}.yml"
  YAML.load_file(file).transform_keys(&:to_sym)
end

# Set up database with test schema & load test models
ActiveRecord::Base.establish_connection(**active_record_connection_properties)
load File.dirname(__FILE__) + '/support/schema.rb'
require File.dirname(__FILE__) + '/support/models'

def database_type
  ActiveRecord::Base.connection.adapter_name.downcase.to_sym
end

def foreign_keys_supported?
  ActiveRecord::Base.connection.supports_foreign_keys?
end

def all_known_models
  ActiveRecord::Base
    .descendants
    .reject { |c| ['ApplicationRecord'].any? { |start| c.name.start_with?(start) } }
    .uniq(&:table_name)
end

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
    DatabaseCleaner.strategy = database_type == :mysql2 ? :truncation : :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
