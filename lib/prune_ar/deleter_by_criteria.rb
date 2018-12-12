# frozen_string_literal: true

require 'logger'
require 'active_record'

module PruneAr
  # Core of this gem. Prunes records based on parameters given.
  class DeleterByCriteria
    attr_reader :criteria, :connection, :logger

    # criteria is of form [['users', "name = 'andrew'"], ['comments', 'id NOT IN (1, 2, 3)']]
    def initialize(
        criteria,
        connection: ActiveRecord::Base.connection,
        logger: Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
      )
      @criteria = criteria
      @connection = connection
      @logger = logger
    end

    def delete
      i = 0
      loop do
        logger.info("deletion loop iteration #{i}")
        i += 1

        return unless anything_to_delete?

        criteria.each do |table, selection|
          delete_selection(table, selection)
        end
      end
    end

    private

    def anything_to_delete?
      criteria.any? do |table, selection|
        count = count_to_be_deleted(table, selection)
        count.positive?.tap do |positive|
          if positive
            logger.info("found something to delete (#{count} records to delete from #{table}"\
                        " where #{selection})")
          end
        end
      end
    end

    def count_to_be_deleted(table, selection)
      results = connection.exec_query("SELECT COUNT(*) as count FROM #{table} WHERE #{selection};")
      results.entries.first['count'].tap do |count|
        logger.debug("found #{count} records to delete from #{table} where #{selection}")
      end
    end

    def delete_selection(table, selection)
      sql = "DELETE FROM #{table} WHERE #{selection};"
      logger.debug("deleting all records from #{table} where #{selection}")
      connection.exec_query(sql)
    end
  end
end
