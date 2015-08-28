class Fleet < ActiveRecord::Base
  has_many :ships
end

class Ship < ActiveRecord::Base
  belongs_to :fleet
  
  has_and_belongs_to_many :sailors
end

class Sailor < ActiveRecord::Base
  has_and_belongs_to_many :sailors
end

