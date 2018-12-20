# frozen_string_literal: true

require 'active_record'
require 'prune_ar/version'
require 'prune_ar/pruner'

# Namespace for all prune_ar code
module PruneAr
  # deletion_criteria
  # => The core pruning criteria that you want to execute (will be executed up front)
  # => {
  # =>   Account => ['accounts.id NOT IN (1, 2)']
  # =>   User => ["users.internal = 'f'", "users.active = 'f'"]
  # => }
  #
  # full_delete_models
  # => Models for which you want to purge all records
  # => [Model1, Model2]
  #
  # pre_queries_to_run
  # => Arbitrary SQL statements to execute before pruning
  # => [ 'UPDATE users SET invited_by_id = NULL WHERE invited_by_id IS NOT NULL' ]
  #
  # conjunctive_deletion_criteria
  # => Pruning criteria you want executed in conjunction with each iteration of pruning
  # => of orphaned records (one case where this is useful if pruning entities which
  # => don't have a belongs_to chain to the entities we pruned but instead are associated
  # => via join tables)
  # => {
  # =>   Image => ['NOT EXISTS (SELECT 1 FROM imagings WHERE imagings.image_id = images.id)']
  # => }
  #
  # perform_sanity_check
  # => Determines whether `PruneAr` sanity checks it's own pruning by setting (& subsequently
  # => removing) foreign key constraints for all belongs_to relations. This is to prove that
  # => we maintained referential integrity.
  def self.prune_all_models(
    deletion_criteria: {},
    full_delete_models: [],
    pre_queries_to_run: [],
    conjunctive_deletion_criteria: {},
    perform_sanity_check: true,
    logger: Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
  )
    Pruner.new(
      models: all_models,
      deletion_criteria: deletion_criteria,
      full_delete_models: full_delete_models,
      pre_queries_to_run: pre_queries_to_run,
      conjunctive_deletion_criteria: conjunctive_deletion_criteria,
      perform_sanity_check: perform_sanity_check,
      logger: logger
    ).prune
  end

  def self.all_models
    ActiveRecord::Base
      .descendants
      .reject { |c| ['ApplicationRecord'].any? { |start| c.name.start_with?(start) } }
      .uniq(&:table_name)
  end
end
