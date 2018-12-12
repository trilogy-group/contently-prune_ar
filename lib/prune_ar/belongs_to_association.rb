# frozen_string_literal: true

module PruneAr
  # Represents a ActiveRecord belongs_to association
  class BelongsToAssociation
    attr_reader :source_model,
                :destination_model,
                :foreign_key_column,
                :association_primary_key_column,
                :foreign_type_column

    def initialize(
      source_model:,
      destination_model:,
      foreign_key_column:,
      association_primary_key_column: 'id',
      foreign_type_column: nil, # Indicates that relation is polymorphic
      **_extra # Ignore extra
    )
      @source_model = source_model
      @destination_model = destination_model
      @foreign_key_column = foreign_key_column
      @association_primary_key_column = association_primary_key_column
      @foreign_type_column = foreign_type_column
    end

    def polymorphic?
      !foreign_type_column.nil?
    end

    def source_table
      source_model.table_name
    end

    def destination_table
      destination_model.table_name
    end

    def destination_model_name
      destination_model.name
    end

    def ==(other) # rubocop:disable Metrics/AbcSize
      source_model == other.source_model &&
        destination_model == other.destination_model &&
        foreign_key_column == other.foreign_key_column &&
        association_primary_key_column == other.association_primary_key_column &&
        foreign_type_column == other.foreign_type_column
    end
  end
end
