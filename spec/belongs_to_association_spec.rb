# frozen_string_literal: true

require 'prune_ar/belongs_to_association'

RSpec.describe PruneAr::BelongsToAssociation do
  let(:simple_creation_params) do
    {
      source_model: Movie,
      destination_model: Genre,
      foreign_key_column: 'genre_id',
      association_primary_key_column: 'id'
    }
  end

  let(:polymorphic_creation_params) do
    simple_creation_params.merge(
      foreign_key_column: 'foreign_id',
      foreign_type_column: 'foreign_type'
    )
  end

  let(:params) { simple_creation_params }
  let(:subject) { PruneAr::BelongsToAssociation.new(**params) }

  describe '#polymorphic?' do
    context 'when not polymorphic' do
      it 'returns false' do
        expect(subject).to_not be_polymorphic
      end
    end

    context 'when polymorphic' do
      let(:params) { polymorphic_creation_params }
      it 'returns true' do
        expect(subject).to be_polymorphic
      end
    end
  end
end
