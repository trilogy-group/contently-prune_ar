# frozen_string_literal: true

require 'prune_ar/foreign_key_handler'
require 'prune_ar/belongs_to_association'

RSpec.describe PruneAr::ForeignKeyHandler do
  let(:subject) { PruneAr::ForeignKeyHandler.new(models: all_known_models) }

  context 'foreign keys unsupported', unless: foreign_keys_supported? do
    let(:foreign_key) do
      ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(
        'movies',
        'genres',
        name: 'should_not_ever_be_set',
        column: 'genre_id',
        primary_key: 'id'
      )
    end

    describe '#original_foreign_keys' do
      it 'is empty' do
        expect(subject.original_foreign_keys).to be_empty
      end
    end

    describe '#drop' do
      it "doesn't raise error" do
        expect { subject.drop([foreign_key]) }.to_not raise_error
      end
    end

    describe '#create' do
      it "doesn't raise error" do
        expect { subject.create([foreign_key]) }.to_not raise_error
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

  let(:connection) { ActiveRecord::Base.connection }

  def create_constraint(conn, constraint)
    conn.add_foreign_key(constraint.from_table, constraint.to_table, constraint.options)
  end

  def drop_constraint(conn, constraint)
    conn.remove_foreign_key(constraint.from_table, name: constraint.name)
  end

  def all_foreign_keys(conn, models)
    models.flat_map { |m| conn.foreign_keys(m.table_name) }
  end

  context 'foreign keys supported', if: foreign_keys_supported? do
    let(:models) { [Movie, Genre] }
    let(:foreign_key) do
      ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(
        'movies',
        'genres',
        {
          name: 'foreign_key_constraint_on_movies_genre_id',
          column: 'genre_id',
          primary_key: 'id',
          on_delete: database_type == :mysql2 ? nil : :restrict,
          on_update: database_type == :mysql2 ? nil : :restrict
        }.merge(database_type == :mysql2 ? {} : { validate: true })
      )
    end

    let(:belongs_to) do
      PruneAr::BelongsToAssociation.new(
        source_model: Movie,
        destination_model: Genre,
        foreign_key_column: 'genre_id'
      )
    end

    describe '#original_foreign_keys' do
      before do
        create_constraint(connection, foreign_key)
      end

      after do
        drop_constraint(connection, foreign_key)
      end

      it 'returns set foreign key constraints' do
        expect(subject.original_foreign_keys).to match_array([foreign_key])
      end
    end

    describe '#drop' do
      before do
        create_constraint(connection, foreign_key)
      end

      after do |example|
        drop_constraint(connection, foreign_key) if example.exception
      end

      it 'drops foreign key constraint' do
        expect(all_foreign_keys(connection, models)).to match_array([foreign_key])
        expect { subject.drop([foreign_key]) }.to_not raise_error
        expect(all_foreign_keys(connection, models)).to be_empty
      end
    end

    describe '#create' do
      after do |example|
        drop_constraint(connection, foreign_key) unless example.exception
      end

      it 'creates the foreign key constraint' do
        expect(all_foreign_keys(connection, models)).to be_empty
        expect { subject.create([foreign_key]) }.to_not raise_error
        expect(all_foreign_keys(connection, models)).to match_array([foreign_key])
      end
    end

    describe '#create_from_belongs_to_associations' do
      after do |example|
        drop_constraint(connection, @foreign_keys.first) unless example.exception
      end

      it 'creates the foreign key constraint' do
        expect(all_foreign_keys(connection, models)).to be_empty
        expect do
          @foreign_keys = subject.create_from_belongs_to_associations([belongs_to])
        end.to_not raise_error
        expect(@foreign_keys.size).to eq 1
        if database_type == :mysql2
          @foreign_keys.first.options.delete(:validate)
          @foreign_keys.first.options[:on_delete] = nil
          @foreign_keys.first.options[:on_update] = nil
        end
        expect(all_foreign_keys(connection, models)).to match_array(@foreign_keys)
      end
    end
  end
end
