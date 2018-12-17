# frozen_string_literal: true

require 'logger'
require 'active_record'

module PruneAr
  # Core of this gem. Prunes records based on parameters given.
  class ForeignKeyHandler
    attr_reader :connection, :logger, :original_foreign_keys, :foreign_key_supported

    def initialize(
        models:,
        connection: ActiveRecord::Base.connection,
        logger: Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
      )
      @connection = connection
      @logger = logger
      @foreign_key_supported = connection.supports_foreign_keys?
      @original_foreign_keys = snapshot_foreign_keys(models)
    end

    def drop(foreign_keys)
      return unless foreign_key_supported

      foreign_keys.each do |fk|
        logger.debug("dropping #{fk.name} from #{fk.from_table} (#{fk.column})")
        connection.remove_foreign_key(fk.from_table, name: fk.name)
      end
    end

    def create(foreign_keys)
      return unless foreign_key_supported

      foreign_keys.each do |fk|
        logger.debug("creating #{fk.name} on #{fk.from_table} (#{fk.column})")
        connection.add_foreign_key(fk.from_table, fk.to_table, fk.options)
      end
    end

    def create_from_belongs_to_associations(associations)
      return [] unless foreign_key_supported

      associations.map do |assoc|
        constraint_name = generate_belongs_to_foreign_key_name(assoc)
        create_from_belongs_to_association(constraint_name, assoc)
      end
    end

    private

    def snapshot_foreign_keys(models)
      return [] unless foreign_key_supported

      models.flat_map do |model|
        connection.foreign_keys(model.table_name)
      end
    end

    def create_from_belongs_to_association(name, assoc)
      fk = ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(
        assoc.source_table,
        assoc.destination_table,
        name: name,
        column: assoc.foreign_key_column,
        primary_key: assoc.association_primary_key_column,
        on_delete: :restrict,
        on_update: :restrict,
        validate: true
      )

      logger.debug("creating #{name} on #{fk.from_table} (#{fk.column})")
      connection.add_foreign_key(fk.from_table, fk.to_table, fk.options)
      fk
    end

    # Limited to 64 characters
    def generate_belongs_to_foreign_key_name(assoc)
      source = assoc.source_table[0..7]
      column = assoc.foreign_key_column[0..7]
      destination = assoc.destination_table[0..7]
      "fk_#{source}_#{column}_#{destination}_#{SecureRandom.hex}"
    end
  end
end
