# frozen_string_literal: true

require 'prune_ar/deleter_by_criteria'

RSpec.describe PruneAr::DeleterByCriteria do
  before do
    Genre.create!(name: 'genre 1')
    Genre.create!(name: 'genre 2')
    Genre.create!(name: 'genre 5')
  end

  let(:criteria) do
    [[Genre.table_name, "name = 'genre 2'"], [Genre.table_name, "name = 'genre 5'"]]
  end

  let(:subject) { PruneAr::DeleterByCriteria.new(criteria) }

  it 'deletes' do
    expect(Genre.count).to eq 3
    subject.delete
    expect(Genre.count).to eq 1
  end
end
