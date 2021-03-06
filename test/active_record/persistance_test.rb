require 'test_helper'

class ActiveRecord::PersistanceTest < ActiveSupport::TestCase

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
      t.text     "assignment"
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

  class TestModelA < ActiveRecord::Base
  end

  class TestModelB < ActiveRecord::Base
    before_save do
      TestModelA.create
    end
  end

  class TestModelC < ActiveRecord::Base
  end

  test '#create with errors' do
    req_stub = webmock(:post, "/fleets").with(
      body: { fleet: {} }.to_json
    ).to_return(
      status: 400,
      body: {name: 'Armada Uno', errors: {name: 'is required'}}.to_json
    )

    fleet = Fleet.create()
    assert_equal ["is required"], fleet.errors[:name]
    assert_requested req_stub
  end

  test '#create' do
    req_stub = webmock(:post, "/fleets").with(
      body: { fleet: {name: 'Armada Uno'} }.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Uno'}.to_json
    )

    Fleet.create(name: 'Armada Uno')

    assert_requested req_stub
  end

  test '#save w/o changes does not trigger a request' do
    webmock(:get, '/fleets', where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Armada Duo'}].to_json
    )

    fleet = Fleet.find(1)
    fleet.save

    assert fleet.save
    assert_equal 1, fleet.id
    assert_equal 'Armada Duo', fleet.name
    
    
    webmock(:get, '/sailors', where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, name: 'Nandor', assignment: 'stay alert'}].to_json
    )

    fleet = Sailor.find(1)
    fleet.save

    assert fleet.save
    assert_equal 1, fleet.id
    assert_equal 'stay alert', fleet.assignment
  end

  test '#save attempts another request while in transaction' do
    webmock(:get, '/test_model_cs/schema').to_return(
      body: {
        attributes: {
          id: {type: 'integer', primary_key: true, null: false, array: false},
          name: {type: 'string', primary_key: false, null: true, array: false}
        }
      }.to_json,
      headers: { 'StandardAPI-Version' => '6.0.0.29' }
    )
    webmock(:get, '/test_model_bs/schema').to_return(
      body: {
        columns: {
          id: {type: 'integer', primary_key: true, null: false, array: false},
          name: {type: 'string', primary_key: false, null: true, array: false}
        }
      }.to_json,
      headers: { 'StandardAPI-Version' => '5.0.0.5' }
    )
    webmock(:get, '/test_model_as/schema').to_return(
      body: {
        columns: {
          id: {type: 'integer', primary_key: true, null: false, array: false},
          name: {type: 'string', primary_key: false, null: true, array: false}
        }
      }.to_json,
      headers: { 'StandardAPI-Version' => '5.0.0.5' }
    )

    assert_raises ActiveRecord::StatementInvalid do
      TestModelB.create
    end
  end



  test '#update clears belongs_to relationship' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: 1, name: 'Armada Uno'}].to_json
    )
    req_stub = webmock(:patch, '/ships/1').with(
      body: {ship: {fleet_id: nil}}.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Uno'}.to_json
    )

    ship = Ship.find(1)
    assert ship.update(fleet: nil)
    assert_requested req_stub
  end

  test '#update' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Armada Uno'}].to_json
    )
    req_stub = webmock(:patch, "/ships").with(
      body: { ship: { name: 'Armada Trio' } }.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Trio'}.to_json
    )

    Ship.find(1).update(name: 'Armada Trio')

    assert_requested req_stub
  end

  test '#update!' do
    webmock(:get, "/ships", where: {id: 1}, limit: 1).to_return(
      body: [{id: 1, fleet_id: nil, name: 'Armada Uno'}].to_json
    )
    req_stub = webmock(:patch, "/ships").with(
      body: { ship: { name: 'Armada Trio' } }.to_json
    ).to_return(
      body: {id: 1, name: 'Armada Trio'}.to_json
    )

    Ship.find(1).update!(name: 'Armada Trio')

    assert_requested req_stub
  end

end
