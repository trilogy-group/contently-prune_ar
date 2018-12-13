# frozen_string_literal: true

module PruneAr
  # Plain object to hold properties of a foreign key constraint
  class ForeignKeyConstraint
    attr_reader :constraint_name,
                :table_name,
                :column_name,
                :foreign_table_name,
                :foreign_column_name,
                :update_rule,
                :delete_rule

    def initialize(
      constraint_name:,
      table_name:,
      column_name:,
      foreign_table_name:,
      foreign_column_name:,
      update_rule: 'NO ACTION',
      delete_rule: 'NO ACTION'
    )
      @constraint_name = constraint_name
      @table_name = table_name
      @column_name = column_name
      @foreign_table_name = foreign_table_name
      @foreign_column_name = foreign_column_name
      @update_rule = update_rule
      @delete_rule = delete_rule
    end

    def ==(other) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      constraint_name == other.constraint_name &&
        table_name == other.table_name &&
        column_name == other.column_name &&
        foreign_table_name == other.foreign_table_name &&
        foreign_column_name == other.foreign_column_name &&
        update_rule == other.update_rule &&
        delete_rule == other.delete_rule
    end
  end
end
