# frozen_string_literal: true

require 'prune_ar/orphaned_selection_builder'

RSpec.describe PruneAr::OrphanedSelectionBuilder do
  let(:simple_assoc) do
    PruneAr::BelongsToAssociation.new(
      source_model: Movie,
      destination_model: Genre,
      foreign_key_column: 'genre_id'
    )
  end

  let(:polymorphic_assoc) do
    PruneAr::BelongsToAssociation.new(
      source_model: Movie,
      destination_model: Genre,
      foreign_key_column: 'foreign_id',
      foreign_type_column: 'foreign_type'
    )
  end

  # rubocop:disable Layout/AlignArray, Lint/PercentStringArray
  describe '#orphaned_selection' do
    it 'correctly generates non-polymorphic query' do
      expect(subject.orphaned_selection(simple_assoc)).to eq(
        %w[
          movies.genre_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM genres dst
            WHERE dst.id = movies.genre_id
          )
        ].join(' ')
      )
    end

    it 'correctly generates polymorphic query' do
      expect(subject.orphaned_selection(polymorphic_assoc)).to eq(
        %w[
          movies.foreign_type = 'Genre'
          AND movies.foreign_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM genres dst
            WHERE dst.id = movies.foreign_id
          )
        ].join(' ')
      )
    end
  end
  # rubocop:enable Layout/AlignArray, Lint/PercentStringArray
end
