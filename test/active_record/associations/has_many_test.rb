require 'test_helper'

class ActiveRecord::Associations::HasManyTest < ActiveSupport::TestCase
  
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
  
  # ID Setters ================================================================
  
  test '#create with has_many_ids=' do
    webmock(:get, "/ships", where: {id: 2}).to_return(body: [{id: 2, fleet_id: nil, name: 'Duo'}].to_json)
    webmock(:post, "/fleets").with(
      body: {
        fleet: {
          name: 'Spanish Armada',
          ships_attributes: [{id: 2}]
        }
      }
    ).to_return(body: {id: 42, name: "Spanish Armada"}.to_json)

    Fleet.create(name: 'Spanish Armada', ship_ids: [2])
  end


  test '#update with has_many_ids=' do
    webmock(:get, "/fleets", where: {id: 42}, limit: 1).to_return(body: [{id: 42, name: "Spanish Armada"}].to_json)
    webmock(:get, "/ships", where:  {id: 2}).to_return(body: [{id: 2, fleet_id: nil, name: 'Duo'}].to_json)
    webmock(:get, "/ships", where:  {fleet_id: 42}).to_return(body: [].to_json)

    webmock(:patch, "/fleets/42").with(
      body: {
        fleet: {
          ships_attributes: [{id: 2}]
        }
    }).to_return(body: {id: 42, name: "Spanish Armada"}.to_json)

    Fleet.find(42).update(ship_ids: ["2"])
  end
  
  # Modifing relationship ====================================================

  test '#save persisted records includes has_many associations when new record added' do
    webmock(:get, '/fleets', where: {id: 1}, limit: 1, include: [:ships]).to_return({
      body: [{
        id: 1,
        name: 'Armada Trio',
        ships: [
          {id: 2, fleet_id: 1, name: 'Definant'}
        ]
      }].to_json
    })
    
    webmock(:get, '/ships', where: {id: 3}, limit: 1).to_return({
      body: [{id: 3, fleet_id: nil, name: 'Enterprise'}].to_json
    })

    req_stub = webmock(:patch, '/fleets/1').with(
      body: {
        fleet: {
          ships_attributes: [{ id: 2 }, {id: 3 }]
        }
      }.to_json
    ).to_return(
      body: {
        id: 1,
        name: 'Armada Trio',
        ships: [{ id: 2, fleet_id: 1, name: 'Voyager' }]
      }.to_json
    )

    # fleet.ships = [ship]
    fleet = Fleet.eager_load(:ships).find(1)
    fleet.update(ships: fleet.ships + [Ship.find(3)])

    assert_requested req_stub
  end

  test '#save persisted records includes has_many associations when replaced with new record' do
    webmock(:get, '/fleets', where: {id: 1}, limit: 1, include: [:ships]).to_return({
      body: [{
        id: 1,
        name: 'Armada Trio',
        ships: [
          {id: 2, fleet_id: 1, name: 'Definant'}
        ]
      }].to_json
    })

    req_stub = webmock(:patch, '/fleets/1').with(
      body: {
        fleet: {
          ships_attributes: [{ name: 'Voyager' }]
        }
      }.to_json
    ).to_return(
      body: {
        id: 1,
        name: 'Armada Trio',
        ships: [{ id: 3, fleet_id: 1, name: 'Voyager' }]
      }.to_json
    )

    # fleet.ships = [ship]
    fleet = Fleet.eager_load(:ships).find(1)
    assert fleet.update(ships: [Ship.new(name: 'Voyager')])
    assert_equal 1, fleet.id
    assert_equal [3], fleet.ships.map(&:id)

    assert_requested req_stub
  end
  
  test '#save persisted records includes has_many associations when updating record in relationship' do
    webmock(:get, '/fleets', where: {id: 1}, limit: 1, include: [:ships]).to_return({
      body: [{
        id: 1,
        name: 'Armada Trio',
        ships: [
          {id: 2, fleet_id: 1, name: 'Definant'}, {id: 3, fleet_id: 1, name: 'Enterprise'}
        ]
      }].to_json
    })
    
    req_stub = webmock(:patch, '/fleets/1').with(
      body: {
        fleet: {
          ships_attributes: [{ name: 'Voyager', id: 2 }, {id: 3}]
        }
      }.to_json
    ).to_return(
      body: {
        id: 1,
        name: 'Armada Trio',
        ships: [{ id: 2, fleet_id: 1, name: 'Voyager' }, {id: 3, fleet_id: 1, name: 'Enterprise'}]
      }.to_json
    )

    # fleet.ships = [ship]
    fleet = Fleet.eager_load(:ships).find(1)
    fleet.ships.first.name = 'Voyager'
    fleet.save

    assert_requested req_stub
  end
  
  test '#save persisted records doesnt include any loaded has_many associations' do
    webmock(:get, '/fleets', where: {id: 1}, limit: 1, include: [:ships]).to_return({
      body: [{
        id: 1,
        name: 'Armada Trio',
        ships: [
          {id: 2, fleet_id: 1, name: 'Definant'}, {id: 3, fleet_id: 1, name: 'Enterprise'}
        ]
      }].to_json
    })
    
    req_stub = webmock(:patch, '/fleets/1').with(
      body: { fleet: { name: 'New NAME!!' } }.to_json
    ).to_return(
      body: {
        id: 1,
        name: 'New NAME!!'
      }.to_json
    )

    # fleet.ships = [ship]
    fleet = Fleet.eager_load(:ships).find(1)
    assert fleet.ships.loaded?
    fleet.name = 'New NAME!!'
    fleet.save

    assert_requested req_stub
  end
  
  # Clearing the relationship =================================================

  test '#update clears has_many relationship' do
    webmock(:get, "/fleets", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Armada Uno'}].to_json
    )
    webmock(:get, "/ships", where: {fleet_id: 1}).to_return(
      body: [{id: 1, name: 'Saucer Trio'}].to_json
    )
    req_stub = webmock(:patch, '/fleets/1').with(
      body: {fleet: {ships_attributes: []}}.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Uno'}.to_json
    )

    fleet = Fleet.find(1)
    assert fleet.update(ships: [])
    assert_requested req_stub
  end

  
  # test 'relation#delete_all' do
  #   webmock(:get, "/fleets", where: {id: 42}, limit: 1).to_return(body: [{id: 42, name: "Spanish Armada"}].to_json)
  #   Fleet.find(42).ships.delete_all
  # end

end
