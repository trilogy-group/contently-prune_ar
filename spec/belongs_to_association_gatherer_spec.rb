# frozen_string_literal: true

require 'prune_ar/belongs_to_association_gatherer'

RSpec.describe PruneAr::BelongsToAssociationGatherer do
  let(:subject) { PruneAr::BelongsToAssociationGatherer.new(models) }

  context 'simple belongs to' do
    # Parent model should not contribute any associations
    let(:models) { [SimpleChildModel, ParentModel, SecondParentModel] }
    it 'returns correct belongs to associations' do
      expect(subject.associations).to match_array([
                                                    PruneAr::BelongsToAssociation.new(
                                                      source_model: SimpleChildModel,
                                                      destination_model: ParentModel,
                                                      foreign_key_column: 'parent_model_id'
                                                    ),
                                                    PruneAr::BelongsToAssociation.new(
                                                      source_model: SimpleChildModel,
                                                      destination_model: SecondParentModel,
                                                      foreign_key_column: 'second_parent_model_id'
                                                    )
                                                  ])
    end
  end

  context 'polymorphic belongs to' do
    # Parent model should not contribute any associations
    let(:models) { [PolymorphicChildModel, ParentModel, SecondParentModel] }

    # Since polymorphic association gathering relies on reading the types from
    # => current records in the table, we need to create some appropriately
    # => parented records
    before do
      parent1 = ParentModel.create!(name: 'parent 1')
      PolymorphicChildModel.create!(name: 'poly 1', parent: parent1)
      parent2 = SecondParentModel.create!(name: 'parent 2')
      PolymorphicChildModel.create!(name: 'poly 2', parent: parent2)
    end

    it 'returns correct belongs to associations' do
      expect(subject.associations).to match_array([
                                                    PruneAr::BelongsToAssociation.new(
                                                      source_model: PolymorphicChildModel,
                                                      destination_model: ParentModel,
                                                      foreign_key_column: 'parent_id',
                                                      foreign_type_column: 'parent_type'
                                                    ),
                                                    PruneAr::BelongsToAssociation.new(
                                                      source_model: PolymorphicChildModel,
                                                      destination_model: SecondParentModel,
                                                      foreign_key_column: 'parent_id',
                                                      foreign_type_column: 'parent_type'
                                                    )
                                                  ])
    end
  end

  context 'simple active record generated HABTM models' do
    let(:habtm_model) do
      ActiveRecord::Base.descendants.find do |m|
        m.table_name == 'parent_models_simple_child_with_join_table_models'
      end
    end

    let(:models) { [ParentModel, SecondParentModel, habtm_model] }

    it 'returns correct belongs to associations' do
      expected = [
        PruneAr::BelongsToAssociation.new(
          source_model: habtm_model,
          destination_model: SimpleChildWithJoinTableModel,
          foreign_key_column: 'simple_child_with_join_table_model_id'
        ),
        PruneAr::BelongsToAssociation.new(
          source_model: habtm_model,
          destination_model: ParentModel,
          foreign_key_column: 'parent_model_id'
        )
      ]
      expect(subject.associations).to match_array(expected)
    end
  end
end
