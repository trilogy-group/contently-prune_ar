# frozen_string_literal: true

require 'prune_ar/foreign_key_handler'
require 'prune_ar/belongs_to_association'

RSpec.describe PruneAr::ForeignKeyHandler do
  describe '#drop' do
    it "doesn't raise error" do
      expect { subject.drop(subject.original_foreign_keys) }.to_not raise_error
    end
  end

  describe '#create' do
    it "doesn't raise error" do
      expect { subject.create(subject.original_foreign_keys) }.to_not raise_error
    end
  end

  describe '#create_from_belongs_to_associations' do
    let(:belongs_to) do
      PruneAr::BelongsToAssociation.new(
        source_model: Movie,
        destination_model: Genre,
        foreign_key_column: 'genre_id'
      )
    end

    it "doesn't raise error" do
      expect { subject.create_from_belongs_to_associations([belongs_to]) }.to_not raise_error
    end
  end
end
