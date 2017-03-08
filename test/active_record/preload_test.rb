require 'test_helper'

class ActiveRecord::PreloadTest < ActiveSupport::TestCase

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

  test '#preload' do
    webmock(:get, "/fleets").to_return(body: [{id: 1}].to_json)
    webmock(:get, "/ships", where: {fleet_id: 1}).to_return(body: [{id: 1, fleet_id: 1}].to_json)
    webmock(:get, "/sailors_ships", where: {ship_id: 1}).to_return(body: [{ship_id: 1, sailor_id: 1}].to_json)
    webmock(:get, "/sailors", where: {id: 1}).to_return(body: [{id: 1}].to_json)
    
    fleets = Fleet.preload(:ships => :sailors)
    assert_equal [1], fleets.map(&:id)
    assert_equal [1], fleets.first.ships.map(&:id)
  end
  
end
