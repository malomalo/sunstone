require 'test_helper'

class ActiveRecord::Associations::HasAndBelongsToManyTest < ActiveSupport::TestCase

  schema do
    create_table "ships" do |t|
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
  
  class Ship < ActiveRecord::Base
    has_and_belongs_to_many :sailors
  end

  class Sailor < ActiveRecord::Base
    has_and_belongs_to_many :ships
  end

  test '#relation_ids' do
    webmock(:get, "/ships", where: {id: 42}, limit: 1).to_return(body: [{id: 42, name: "The Niña"}].to_json)
    webmock(:get, "/sailors", where: {sailors_ships: {ship_id: {eq: 42}}}).to_return(body: [{id: 43, name: "Chris"}].to_json)

    assert_equal [43], Ship.find(42).sailor_ids
  end

  test '#update habtm relationships' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Armada Uno'}].to_json
    )
    webmock(:get, "/sailors", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Captain'}].to_json
    )
    webmock(:get, "/sailors", where: {sailors_ships: {ship_id: {eq: 1}}}).to_return(
      body: [].to_json
    )
    req_stub = webmock(:patch, '/ships/1').with(
      body: {ship: {sailors_attributes: [{id: 1}]}}.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Uno'}.to_json
    )

    ship = Ship.find(1)
    assert ship.update(sailors: [Sailor.find(1)])
    assert_requested req_stub
  end
  
  test '#update clears habtm relationship' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Armada Uno'}].to_json
    )
    webmock(:get, "/sailors", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Captain'}].to_json
    )
    webmock(:get, "/sailors", where: {sailors_ships: {ship_id: {eq: 1}}}).to_return(
      body: [{id: 1, name: 'Captain'}].to_json
    )
    req_stub = webmock(:patch, '/ships/1').with(
      body: {ship: {sailors_attributes: []}}.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Uno'}.to_json
    )

    ship = Ship.find(1)
    assert ship.update(sailors: [])
    assert_requested req_stub
  end
  
  test '#save persisted record doesnt include loaded habtm association' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Armada Uno'}].to_json
    )
    webmock(:get, "/sailors", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Captain'}].to_json
    )
    webmock(:get, "/sailors", where: {sailors_ships: {ship_id: {eq: 1}}}).to_return(
      body: [{id: 1, name: 'Captain'}].to_json
    )
    
    ship = Ship.find(1)
    
    
    req_stub = webmock(:patch, '/ships/1').with(
      body: {
        ship: { name: 'New NAME!!' }
      }.to_json
    ).to_return(
      body: {
        id: 1,
        name: 'New NAME!!'
      }.to_json
    )
    
    ship.sailors.load
    assert ship.sailors.loaded?
    ship.name = 'New NAME!!'
    assert ship.save

    assert_requested req_stub
  end
  
  
  test "#destroy with habtm relationship" do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Armada Uno'}].to_json
    )
    req_stub = webmock(:delete, '/ships/1').to_return(
      status: 204
    )

    ship = Ship.find(1)
    assert ship.destroy
    assert_requested req_stub
  end


end
