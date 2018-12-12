# frozen_string_literal: true

require 'logger'
require 'active_record'
require 'prune_ar/foreign_key_constraint'

module PruneAr
  # Core of this gem. Prunes records based on parameters given.
  class ForeignKeyHandler
    attr_reader :connection, :logger, :original_foreign_keys, :foreign_key_supported

    def initialize(
        connection: ActiveRecord::Base.connection,
        logger: Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
      )
      @connection = connection
      @logger = logger
      @foreign_key_supported = connection.adapter_name.downcase.to_sym == :postgresql
      @original_foreign_keys = snapshot_foreign_keys
    end

    def drop(foreign_keys)
      return unless foreign_key_supported

      foreign_keys.each do |fk|
        logger.debug("dropping #{fk.constraint_name} from #{fk.table_name} (#{fk.column_name})")
        connection.exec_query("ALTER TABLE #{fk.table_name} DROP CONSTRAINT #{fk.constraint_name};")
      end
    end

    def create(foreign_keys)
      return unless foreign_key_supported

      foreign_keys.each do |fk|
        logger.debug("creating #{fk.constraint_name} on #{fk.table_name} (#{fk.column_name})")
        connection.exec_query(create_sql(fk))
      end
    end

    def create_from_belongs_to_associations(associations)
      return [] unless foreign_key_supported

      associations.map do |assoc|
        constraint_name = "fk_#{assoc.source_table}_#{assoc.foreign_key_column}"\
                          "_#{assoc.destination_table}_id_#{SecureRandom.hex}"
        create_from_belongs_to_association(constraint_name, assoc)
      end
    end

    private

    def snapshot_foreign_keys
      return [] unless foreign_key_supported

      connection.exec_query(snapshot_sql).map do |row|
        ForeignKeyConstraint.new(**row.transform_keys(&:to_sym))
      end
    end

    def create_from_belongs_to_association(name, assoc)
      fk = ForeignKeyConstraint.new(
        constraint_name: name,
        table_name: assoc.source_table,
        column_name: assoc.foreign_key_column,
        foreign_table_name: assoc.destination_table,
        foreign_column_name: assoc.association_primary_key_column
      )

      logger.debug("creating #{name} on #{fk.table_name} (#{fk.column_name})")
      connection.exec_query(create_sql(fk))

      fk
    end

    def snapshot_sql
      sql = <<~SQL
        SELECT tc.constraint_name,
               tc.table_name,
               kcu.column_name,
               ccu.table_name AS foreign_table_name,
               ccu.column_name AS foreign_column_name,
               rc.update_rule AS update_rule,
               rc.delete_rule AS delete_rule
        FROM information_schema.table_constraints tc
        INNER JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
        INNER JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
        INNER JOIN information_schema.referential_constraints rc ON rc.constraint_name = tc.constraint_name
        WHERE constraint_type = 'FOREIGN KEY'
        AND tc.table_catalog = '#{connection.current_database}';
      SQL

      sql.gsub(/\s+/, ' ').strip
    end

    def create_sql(foreign_key)
      on_delete = foreign_key.delete_rule ? "ON DELETE #{foreign_key.delete_rule}" : ''
      on_update = foreign_key.update_rule ? "ON UPDATE #{foreign_key.update_rule}" : ''
      sql = <<~SQL
        ALTER TABLE #{foreign_key.table_name}
        ADD CONSTRAINT #{foreign_key.constraint_name}
        FOREIGN KEY (#{foreign_key.column_name})
        REFERENCES #{foreign_key.foreign_table_name}(#{foreign_key.foreign_column_name})
        #{on_delete}
        #{on_update};
      SQL

      sql.gsub(/\s+/, ' ').strip
    end
  end
end
