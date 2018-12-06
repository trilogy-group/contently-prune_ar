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
      update_rule: nil,
      delete_rule: nil
    )
      @constraint_name = constraint_name
      @table_name = table_name
      @column_name = column_name
      @foreign_table_name = foreign_table_name
      @foreign_column_name = foreign_column_name
      @update_rule = update_rule
      @delete_rule = delete_rule
    end
  end
end
