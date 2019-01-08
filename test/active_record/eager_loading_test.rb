require 'test_helper'

class ActiveRecord::EagerLoadingTest < ActiveSupport::TestCase

  schema do
    create_table "ships" do |t|
      t.string   "name",                    limit: 255
      t.integer  "fleet_id"
    end

    create_table "fleets" do |t|
      t.string   "name",                    limit: 255
    end
    
    create_table "sailors" do |t|
      t.string   "name",                    limit: 255
    end
    
    create_table "sailors_ships", id: false do |t|
      t.integer  "ship_id",                 null: false
      t.integer  "sailor_id",               null: false
    end
    
  end
  
  class Fleet < ActiveRecord::Base
    has_many :ships
  end

  class Ship < ActiveRecord::Base
    belongs_to :fleet
  
    has_and_belongs_to_many :sailors
  end

  class Sailor < ActiveRecord::Base
    has_and_belongs_to_many :ships
  end

  test '#eager_load' do
    webmock(:get, "/fleets", include: [{:ships => :sailors}]).to_return(body: [{
      id: 1, ships: [{id: 1, fleet_id: 1}]
    }].to_json)
    
    fleets = Fleet.eager_load(ships: :sailors)
    assert_equal [1], fleets.map(&:id)
    assert_equal [1], fleets.first.ships.map(&:id)
  end
  

  test '#eager_loads' do
    assert_equal <<-SQL, Fleet.eager_load(ships: :sailors).limit(2).to_sql
      SELECT DISTINCT "fleets"."id"
      FROM "fleets"
      LEFT OUTER JOIN "ships" ON "ships"."fleet_id" = "fleets"."id"
      LEFT OUTER JOIN "sailors" ON "sailors"."ship_id" = "ships"."id"
      LIMIT 2
    SQL



  end

end