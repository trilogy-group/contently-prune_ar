# frozen_string_literal: true

require 'logger'
require 'active_record'
require 'prune_ar/belongs_to_association'

module PruneAr
  # Given ActiveRecord models, produces BelongsToAssociation objects
  class BelongsToAssociationGatherer
    attr_reader :models, :connection, :logger

    def initialize(
      models,
      connection: ActiveRecord::Base.connection,
      logger: Logger.new(STDOUT).tap { |l| l.level = Logger::WARN }
    )
      @models = models
      @connection = connection
      @logger = logger
    end

    def associations
      @associations ||= gather_belongs_to_for_models
    end

    private

    def gather_belongs_to_for_models
      models.flat_map(&method(:gather_belongs_to_for_model))
    end

    def gather_belongs_to_for_model(source_model)
      source_model.reflect_on_all_associations.flat_map do |assoc|
        next [] if assoc.macro != :belongs_to

        build_belongs_to_associations(source_model, assoc)
      end
    end

    def build_belongs_to_associations(source_model, assoc)
      destination_models = gather_belongs_to_destination_models(source_model, assoc)
      curried = method(:build_belongs_to_association).curry.call(source_model, assoc)
      destination_models.flat_map(&curried)
    end

    def validate_belongs_to_association(foreign_key_column, source_model, destination_model)
      unless destination_model.column_names.include?('id')
        logger.warn("bad association? Column #{destination_model.table_name}.id doesn't exist")
        return false
      end

      unless source_model.column_names.include?(foreign_key_column)
        logger.warn("bad association? Column #{source_model.table_name}.#{foreign_key_column}"\
                    " doesn't exist")
        return false
      end

      true
    end

    def build_belongs_to_association(source_model, assoc, destination_model)
      foreign_key_column = get_foreign_key_column(assoc, destination_model)
      unless validate_belongs_to_association(foreign_key_column, source_model, destination_model)
        return []
      end

      [
        BelongsToAssociation.new(
          {
            source_model: source_model,
            destination_model: destination_model,
            foreign_key_column: foreign_key_column
          }.merge(assoc.polymorphic? ? { foreign_type_column: assoc.foreign_type.to_s } : {})
        )
      ]
    end

    def gather_belongs_to_destination_models(source_model, assoc)
      begin
        return [assoc.klass] unless assoc.polymorphic?
      rescue StandardError => e
        logger.error("error encountered loading association class: #{e}")
        return []
      end

      foreign_types = read_foreign_types(source_model, assoc)
      foreign_types.flat_map(&method(:model_string_to_class))
    end

    def read_foreign_types(source_model, assoc)
      foreign_type_column = assoc.foreign_type.to_s

      sql = <<~SQL
        SELECT DISTINCT #{foreign_type_column}
        FROM #{source_model.table_name}
        WHERE #{foreign_type_column} IS NOT NULL
      SQL

      sql = sql.gsub(/\s+/, ' ').strip

      begin
        foreign_types = connection.exec_query(sql).map { |t| t[foreign_type_column] }
      rescue StandardError => e
        logger.error("error encountered reading foreign types for #{source_model}: #{e}")
        return []
      end

      foreign_types
    end

    def get_foreign_key_column(assoc, destination_model)
      foreign_key = assoc.foreign_key.to_s

      # Rails strangeness on HABTM. `assoc.foreign_key` shows up as `left_side_id` for one
      # => field in the join table.
      if foreign_key == 'left_side_id'
        foreign_key = destination_model.table_name.gsub(/s\z/, '') + '_id'
      end

      foreign_key
    end

    def model_string_to_class(type_string)
      [type_string.constantize]
    rescue StandardError => e
      logger.error("error encountered constantizing #{type_string}: #{e}")
      []
    end
  end
end
