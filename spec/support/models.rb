# frozen_string_literal: true

require 'active_record'

class Genre < ActiveRecord::Base
end

class Movie < ActiveRecord::Base
  belongs_to :genre
end

class ParentModel < ActiveRecord::Base
  has_many :simple_child_models
  has_many :polymorphic_child_models, as: :parent
  has_and_belongs_to_many :simple_child_with_join_table_models
  has_many :sub_parent_models
end

class SecondParentModel < ActiveRecord::Base
  has_many :polymorphic_child_models, as: :parent
end

class SubParentModel < ActiveRecord::Base
  belongs_to :parent_model
  has_many :polymorphic_child_models, as: :parent
end

class SimpleChildModel < ActiveRecord::Base
  belongs_to :parent_model
  belongs_to :second_parent_model
end

class PolymorphicChildModel < ActiveRecord::Base
  belongs_to :parent, polymorphic: true
end

class SimpleChildWithJoinTableModel < ActiveRecord::Base
  has_and_belongs_to_many :parent_models
end
