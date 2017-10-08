require 'test_helper'

class ActiveRecord::Associations::BelongsToTest < ActiveSupport::TestCase

  schema do
    create_table "ships" do |t|
      t.string   "name",                    limit: 255
      t.integer  "fleet_id"
    end

    create_table "fleets" do |t|
      t.string   "name",                    limit: 255
    end
  end

  class Fleet < ActiveRecord::Base
    has_many :ships
  end

  class Ship < ActiveRecord::Base
    belongs_to :fleet
  end
  
  # Save includes =============================================================

  test '#save new record includes new belongs_to associations' do
    ship = Ship.new(name: 'Definant', fleet: Fleet.new(name: 'Armada Duo'))
    
    req_stub = webmock(:post, '/ships', {include: :fleet}).with(
      body: {
        ship: { name: 'Definant', fleet_attributes: { name: 'Armada Duo' } }
      }.to_json
    ).to_return(
      body: {
        id: 2,
        fleet_id: 3,
        name: 'Definant 001',
        fleet: { id: 3, name: 'Armada 2' }
      }.to_json
    )
    
    assert ship.save
    assert_equal 2, ship.id
    assert_equal 3, ship.fleet_id
    assert_equal 3, ship.fleet.id
    assert_equal 'Definant 001', ship.name
    assert_equal 'Armada 2', ship.fleet.name
    
    assert_requested req_stub
  end
  
  test '#save new record doesnt include persisted/unmodified belongs_to associations' do
    webmock(:get, "/fleets", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Armada Original'}].to_json
    )
    
    fleet = Fleet.find(1)
    ship = Ship.new(name: 'Definant', fleet: fleet)
    
    req_stub = webmock(:post, '/ships').with(
      body: {
        ship: { name: 'Definant', fleet_id: 1 }
      }.to_json
    ).to_return(
      body: {
        id: 2,
        fleet_id: 1,
        name: 'Definant 001'
      }.to_json
    )
    
    assert ship.save
    assert_equal 2, ship.id
    assert_equal 1, ship.fleet_id
    
    assert_requested req_stub
  end
  
  test '#save persisted record includes new belongs_to associations' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Ship Uno'}].to_json
    )

    req_stub = webmock(:patch, '/ships/1', {include: :fleet}).with(
      body: {
        ship: { fleet_attributes: { name: 'Armada Duo' } }
      }.to_json
    ).to_return(
      body: {
        id: 1, fleet_id: 2, name: 'Ship Uno',
        fleet: { id: 2, name: 'Armada Duo' }
      }.to_json
    )

    ship = Ship.find(1)
    ship.fleet = Fleet.new(name: 'Armada Duo')

    ship.save
    
    assert_requested req_stub
  end
  
  test '#save persisted record doesnt include persisted/unmodified belongs_to associations but updates belongs_to key' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Ship Uno'}].to_json
    )
    webmock(:get, "/fleets", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Armada Original'}].to_json
    )
    
    fleet = Fleet.find(1)
    ship = Ship.find(1)
    
    req_stub = webmock(:patch, '/ships/1').with(
      body: {
        ship: { fleet_id: 1 }
      }.to_json
    ).to_return(
      body: {
        id: 1,
        fleet_id: 1,
        name: 'My Ship'
      }.to_json
    )
    
    ship.fleet = fleet
    assert ship.save
    assert_equal 1, ship.id
    assert_equal 1, ship.fleet_id
    assert_equal 'My Ship', ship.name
    
    assert_requested req_stub
  end

  test '#save persisted record doesnt include loaded belongs_to association' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1, include: [:fleet]).to_return(
      body: [{id: 1, fleet_id: 1, name: 'Ship Uno', fleet: {id: 1, name: 'Armada Original'}}].to_json
    )
    
    ship = Ship.eager_load(:fleet).find(1)
    
    req_stub = webmock(:patch, '/ships/1').with(
      body: {
        ship: { name: 'New NAME!!' }
      }.to_json
    ).to_return(
      body: {
        id: 1,
        fleet_id: 1,
        name: 'New NAME!!'
      }.to_json
    )


    assert ship.association(:fleet).loaded?
    ship.name = 'New NAME!!'
    assert ship.save

    assert_requested req_stub
  end

end
