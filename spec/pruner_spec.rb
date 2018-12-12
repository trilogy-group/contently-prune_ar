# frozen_string_literal: true

require 'prune_ar/pruner'

# This is more of a sanity check than an exhaustive/complete set of tests
RSpec.describe PruneAr::Pruner do
  describe '#prune' do
    context 'simple one parent' do
      before do
        @parents = [
          ParentModel.create!(name: 'parent_0'), # will live
          ParentModel.create!(name: 'parent_1'),
          ParentModel.create!(name: 'parent_2')
        ]

        @children = [
          SimpleChildModel.create!(name: 'child_0', parent_model: @parents[0]), # will live
          SimpleChildModel.create!(name: 'child_1'), # will live
          SimpleChildModel.create!(name: 'child_2', parent_model: @parents[1]),
          SimpleChildModel.create!(name: 'child_3', parent_model: @parents[2]),
          SimpleChildModel.create!(name: 'child_4', parent_model: @parents[2])
        ]
      end

      let(:models) { [ParentModel, SimpleChildModel] }
      let(:deletion_criteria) { { ParentModel => ["name = 'parent_2'", "name = 'parent_1'"] } }

      it 'works' do
        expect(ParentModel.count).to eq(@parents.size)
        expect(SimpleChildModel.count).to eq(@children.size)
        expect do
          PruneAr::Pruner.new(
            models: models,
            deletion_criteria: deletion_criteria
            # logger: Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
          ).prune
        end.to_not raise_error
        expect(ParentModel.all).to match_array(@parents[0..0])
        expect(SimpleChildModel.all).to match_array(@children[0..1])
      end
    end

    context 'simple multi parent' do
      before do
        @parents = [
          ParentModel.create!(name: 'parent_0'), # will live
          ParentModel.create!(name: 'parent_1'),
          ParentModel.create!(name: 'parent_2')
        ]

        @second_parents = [
          SecondParentModel.create!(name: 'second_parent_0'), # will live
          SecondParentModel.create!(name: 'second_parent_1'),
          SecondParentModel.create!(name: 'second_parent_2')
        ]

        @children = [
          SimpleChildModel.create!(name: 'child_0', parent_model: @parents[0]), # will live
          SimpleChildModel.create!(name: 'child_1', second_parent_model: @second_parents[0]), # will live
          SimpleChildModel.create!(name: 'child_2', parent_model: @parents[1]),
          SimpleChildModel.create!(name: 'child_3', second_parent_model: @second_parents[2]),
          SimpleChildModel.create!(name: 'child_4', parent_model: @parents[2], second_parent_model: @second_parents[2])
        ]
      end

      let(:models) { [ParentModel, SimpleChildModel] }
      let(:deletion_criteria) do
        {
          ParentModel => ["name = 'parent_2'", "name = 'parent_1'"],
          SecondParentModel => ["name = 'second_parent_1'", "name = 'second_parent_2'"]
        }
      end

      it 'works' do
        expect(ParentModel.count).to eq(@parents.size)
        expect(SecondParentModel.count).to eq(@second_parents.size)
        expect(SimpleChildModel.count).to eq(@children.size)
        expect do
          PruneAr::Pruner.new(
            models: models,
            deletion_criteria: deletion_criteria
            # logger: Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
          ).prune
        end.to_not raise_error
        expect(ParentModel.all).to match_array(@parents[0..0])
        expect(SecondParentModel.all).to match_array(@second_parents[0..0])
        expect(SimpleChildModel.all).to match_array(@children[0..1])
      end
    end

    context 'polymorphic & parent chain' do
      before do
        @parents = [
          ParentModel.create!(name: 'parent_0'), # will live
          ParentModel.create!(name: 'parent_1'),
          ParentModel.create!(name: 'parent_2')
        ]

        @sub_parents = [
          SubParentModel.create!(name: 'sub_parent_0', parent_model: @parents[0]), # will live
          SubParentModel.create!(name: 'sub_parent_1'), # will live
          SubParentModel.create!(name: 'sub_parent_2', parent_model: @parents[1]),
          SubParentModel.create!(name: 'sub_parent_3', parent_model: @parents[2]),
          SubParentModel.create!(name: 'sub_parent_4', parent_model: @parents[2])
        ]

        @children = [
          PolymorphicChildModel.create!(name: 'child_0', parent: @parents[0]),
          PolymorphicChildModel.create!(name: 'child_1', parent: @sub_parents[0]),
          PolymorphicChildModel.create!(name: 'child_2', parent: @sub_parents[1]),
          PolymorphicChildModel.create!(name: 'child_3', parent: @parents[1]),
          PolymorphicChildModel.create!(name: 'child_4', parent: @sub_parents[2])
        ]
      end

      let(:models) { [ParentModel, SubParentModel, PolymorphicChildModel] }
      let(:deletion_criteria) { { ParentModel => ["name = 'parent_2'", "name = 'parent_1'"] } }

      it 'works' do
        expect(ParentModel.count).to eq(@parents.size)
        expect(SubParentModel.count).to eq(@sub_parents.size)
        expect(PolymorphicChildModel.count).to eq(@children.size)
        expect do
          PruneAr::Pruner.new(
            models: models,
            deletion_criteria: deletion_criteria
            # logger: Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
          ).prune
        end.to_not raise_error
        expect(ParentModel.all).to match_array(@parents[0..0])
        expect(SubParentModel.all).to match_array(@sub_parents[0..1])
        expect(PolymorphicChildModel.all).to match_array(@children[0..2])
      end
    end

    context 'has and belongs to many join table' do
      before do
        @parents = [
          ParentModel.create!(name: 'parent_0'), # will live
          ParentModel.create!(name: 'parent_1'),
          ParentModel.create!(name: 'parent_2')
        ]

        # All will survive
        @other_sides = [
          SimpleChildWithJoinTableModel.create!(name: 'child_0', parent_models: @parents[0..2]), # 1 surviving row
          SimpleChildWithJoinTableModel.create!(name: 'child_1', parent_models: @parents[0..0]), # 1 surviving row
          SimpleChildWithJoinTableModel.create!(name: 'child_2', parent_models: @parents[1..2]),
          SimpleChildWithJoinTableModel.create!(name: 'child_3', parent_models: @parents[1..1]),
          SimpleChildWithJoinTableModel.create!(name: 'child_4', parent_models: @parents[2..2])
        ]
      end

      let(:habtm_model) do
        ActiveRecord::Base.descendants.find do |m|
          m.table_name == 'parent_models_simple_child_with_join_table_models'
        end
      end

      let(:models) { [ParentModel, SimpleChildWithJoinTableModel, habtm_model] }
      let(:deletion_criteria) { { ParentModel => ["name = 'parent_2'", "name = 'parent_1'"] } }

      it 'works' do
        expect(ParentModel.count).to eq(@parents.size)
        expect(SimpleChildWithJoinTableModel.count).to eq(@other_sides.size)
        expect(habtm_model.count).to eq(@other_sides.inject(0) { |acc, o| acc + o.parent_models.count })
        expect do
          PruneAr::Pruner.new(
            models: models,
            deletion_criteria: deletion_criteria
            # logger: Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
          ).prune
        end.to_not raise_error
        expect(ParentModel.all).to match_array(@parents[0..0])
        expect(SimpleChildWithJoinTableModel.all).to match_array(@other_sides)
        expect(habtm_model.count).to eq 2
      end
    end
  end
end
