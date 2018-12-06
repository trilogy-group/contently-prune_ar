# frozen_string_literal: true

require 'logger'
require 'active_record'
require 'prune_ar/belongs_to_association_gatherer'
require 'prune_ar/orphaned_selection_builder'
require 'prune_ar/deleter_by_criteria'
require 'prune_ar/foreign_key_handler'

module PruneAr
  # Core of this gem. Prunes records based on parameters given.
  class Pruner
    attr_reader :associations,
                :deletion_criteria,
                :full_delete_models,
                :pre_queries_to_run,
                :conjunctive_deletion_criteria,
                :logger,
                :foreign_key_handler

    def initialize(
      models:,
      deletion_criteria: {},
      full_delete_models: [],
      pre_queries_to_run: [],
      conjunctive_deletion_criteria: {},
      logger: Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
    )
      @associations = BelongsToAssociationGatherer.new(models, connection: connection).associations
      @full_delete_models = full_delete_models
      @pre_queries_to_run = pre_queries_to_run
      @deletion_criteria = deletion_criteria
      @conjunctive_deletion_criteria = conjunctive_deletion_criteria
      @logger = logger
      @foreign_key_handler = ForeignKeyHandler.new(connection: connection, logger: logger)
    end

    def prune
      # This transaction is helpful when developing/working on this code. If a SQL statement errors,
      # => it leaves the database untouched.
      connection.transaction do
        prune_core
      end
    end

    private

    def prune_core
      drop_original_foreign_key_constraints

      # Run any pre-queries we were told to run
      pre_queries

      # Delete using deletion_criteria before we sanitize anything
      pre_delete

      # Truncate tables we were told to wipe completely
      full_delete

      # Main deletion (conjunctive_deletion_criteria + orphaned records)
      main_delete

      # Now that there are no violations, create foreign key constraints on all :belongs_to
      # => this is a sanity check that we eliminated violations
      # => this ignores polymorphic relations since FKs cannot be set on polymorphic :belongs_to
      # => these foreign key constraints are dropped right after since they're only for sanity
      foreign_key_sanity_check

      recreate_original_foreign_key_constraints
    end

    def drop_original_foreign_key_constraints
      logger.info('dropping existing foreign key constraints')
      foreign_key_handler.drop(foreign_key_handler.original_foreign_keys)
    end

    def recreate_original_foreign_key_constraints
      logger.info('recreating original foreign key constraints')
      foreign_key_handler.create(foreign_key_handler.original_foreign_keys)
    end

    def pre_queries
      logger.info('running pre_queries_to_run')
      pre_queries_to_run.each do |sql|
        logger.debug("running pre-query #{sql}")
        connection.exec_query(sql)
      end
    end

    def pre_delete
      logger.info('deleting via deletion_criteria')
      DeleterByCriteria.new(
        flatten_deletion_criteria(deletion_criteria),
        connection: connection,
        logger: logger
      ).delete
    end

    def full_delete
      logger.info('truncating full_delete_models')
      full_delete_models.each do |model|
        logger.debug("truncating #{model}")
        connection.exec_query("TRUNCATE #{model.table_name};")
      end
    end

    def main_delete
      logger.info('deleting via conjunctive_deletion_criteria & pruning orphaned records')
      association_deletion_criteria = flat_associations_deletion_criteria(associations)
      flat_conjunctive_criteria = flatten_deletion_criteria(conjunctive_deletion_criteria)
      DeleterByCriteria.new(
        (association_deletion_criteria + flat_conjunctive_criteria).sort,
        connection: connection,
        logger: logger
      ).delete
    end

    def foreign_key_sanity_check
      logger.info('sanity checking via foreign key constraints')
      created_foreign_keys = foreign_key_handler.create_from_belongs_to_associations(
        associations.reject(&:polymorphic?)
      )

      foreign_key_handler.drop(created_foreign_keys)
    end

    def flat_associations_deletion_criteria(associations)
      associations.map do |assoc|
        [assoc.source_table, orphaned_selection_builder.orphaned_selection(assoc)]
      end
    end

    def flatten_deletion_criteria(criteria)
      criteria.flat_map do |model, selections|
        selections.map { |s| [model.table_name, s] }
      end
    end

    def connection
      @connection ||= ActiveRecord::Base.connection
    end

    def orphaned_selection_builder
      @orphaned_selection_builder ||= OrphanedSelectionBuilder.new
    end
  end
end
