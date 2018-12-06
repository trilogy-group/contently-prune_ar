# frozen_string_literal: true

module PruneAr
  # Builds SQL selection to select orphaned records based on a BelongsToAssociation
  class OrphanedSelectionBuilder
    def initialize
      @cache = {}
    end

    def orphaned_selection(assoc)
      @cache[assoc] ||= self.class.build_orphaned_selection(assoc)
    end

    def self.build_orphaned_selection(assoc)
      if assoc.polymorphic?
        build_orphaned_selection_polymorphic(assoc)
      else
        build_orphaned_selection_simple(assoc)
      end
    end

    def self.build_orphaned_selection_simple(assoc)
      src = assoc.source_table
      dst = assoc.destination_table
      sql = <<~SQL
        #{src}.#{assoc.foreign_key_column} IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM #{dst} dst
          WHERE dst.#{assoc.association_primary_key_column} = #{src}.#{assoc.foreign_key_column}
        )
      SQL

      sql.gsub(/\s+/, ' ').strip
    end

    def self.build_orphaned_selection_polymorphic(assoc)
      src = assoc.source_table
      dst = assoc.destination_table
      sql = <<~SQL
        #{src}.#{assoc.foreign_type_column} = '#{assoc.destination_model_name}'
        AND #{src}.#{assoc.foreign_key_column} IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM #{dst} dst
          WHERE dst.#{assoc.association_primary_key_column} = #{src}.#{assoc.foreign_key_column}
        )
      SQL

      sql.gsub(/\s+/, ' ').strip
    end
  end
end
