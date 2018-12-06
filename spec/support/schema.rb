# frozen_string_literal: true

require 'active_record'

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :genres, force: :cascade do |t|
    t.string :name
  end

  create_table :movies, force: :cascade do |t|
    t.string :name
    t.integer :genre_id
  end

  create_table :parent_models, force: :cascade do |t|
    t.string :name
  end

  create_table :second_parent_models, force: :cascade do |t|
    t.string :name
  end

  create_table :sub_parent_models, force: :cascade do |t|
    t.string :name
    t.integer :parent_model_id
  end

  create_table :simple_child_models, force: :cascade do |t|
    t.string :name
    t.integer :parent_model_id
    t.integer :second_parent_model_id
    t.integer :sub_parent_model_id
  end

  create_table :polymorphic_child_models, force: :cascade do |t|
    t.string :name
    t.integer :parent_id
    t.string :parent_type
  end

  create_table :simple_child_with_join_table_models, force: :cascade do |t|
    t.string :name
  end

  create_table :parent_models_simple_child_with_join_table_models, force: :cascade do |t|
    t.integer :parent_model_id
    t.integer :simple_child_with_join_table_model_id
  end
end
