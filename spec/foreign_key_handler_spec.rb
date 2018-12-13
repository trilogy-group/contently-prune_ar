# frozen_string_literal: true

require 'prune_ar/foreign_key_handler'
require 'prune_ar/belongs_to_association'

RSpec.describe PruneAr::ForeignKeyHandler do
  context 'foreign keys unsupported', unless: foreign_keys_supported? do
    let(:foreign_key) do
      PruneAr::ForeignKeyConstraint.new(
        constraint_name: 'should_not_ever_be_set',
        table_name: 'movies',
        column_name: 'genre_id',
        foreign_table_name: 'genres',
        foreign_column_name: 'id'
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
    sql = <<~SQL
      ALTER TABLE #{constraint.table_name}
      ADD CONSTRAINT #{constraint.constraint_name}
      FOREIGN KEY (#{constraint.column_name})
      REFERENCES #{constraint.foreign_table_name}(#{constraint.foreign_column_name})
      ON DELETE #{constraint.delete_rule}
      ON UPDATE #{constraint.update_rule};
    SQL

    conn.exec_query(sql)
  end

  def drop_constraint(conn, constraint)
    conn.exec_query(
      <<~SQL
        ALTER TABLE #{constraint.table_name}
        DROP CONSTRAINT #{constraint.constraint_name};
      SQL
    )
  end

  def all_foreign_keys(conn)
    sql = <<~SQL
      SELECT tc.constraint_name, tc.table_name, kcu.column_name,
             ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name,
             rc.update_rule AS update_rule, rc.delete_rule AS delete_rule
      FROM information_schema.table_constraints tc
      INNER JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
      INNER JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
      INNER JOIN information_schema.referential_constraints rc ON rc.constraint_name = tc.constraint_name
      WHERE constraint_type = 'FOREIGN KEY'
      AND tc.table_catalog = '#{conn.current_database}';
    SQL

    conn.exec_query(sql).map do |row|
      PruneAr::ForeignKeyConstraint.new(**row.transform_keys(&:to_sym))
    end
  end

  context 'foreign keys supported', if: foreign_keys_supported? do
    let(:foreign_key) do
      PruneAr::ForeignKeyConstraint.new(
        constraint_name: 'foreign_key_constraint_on_movies_genre_id',
        table_name: 'movies',
        column_name: 'genre_id',
        foreign_table_name: 'genres',
        foreign_column_name: 'id'
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
        expect(all_foreign_keys(connection)).to match_array([foreign_key])
        expect { subject.drop([foreign_key]) }.to_not raise_error
        expect(all_foreign_keys(connection)).to be_empty
      end
    end

    describe '#create' do
      after do |example|
        drop_constraint(connection, foreign_key) unless example.exception
      end

      it 'creates the foreign key constraint' do
        expect(all_foreign_keys(connection)).to be_empty
        expect { subject.create([foreign_key]) }.to_not raise_error
        expect(all_foreign_keys(connection)).to match_array([foreign_key])
      end
    end

    describe '#create_from_belongs_to_associations' do
      after do |example|
        drop_constraint(connection, @foreign_keys.first) unless example.exception
      end

      it 'creates the foreign key constraint' do
        expect(all_foreign_keys(connection)).to be_empty
        expect do
          @foreign_keys = subject.create_from_belongs_to_associations([belongs_to])
        end.to_not raise_error
        expect(@foreign_keys.size).to eq 1
        expect(all_foreign_keys(connection)).to match_array(@foreign_keys)
      end
    end
  end
end
