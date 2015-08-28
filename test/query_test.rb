require 'test_helper'

class QueryTest < Minitest::Test

  def setup
    stub_request(:get, "malomalo.io/ping").to_return(:body => "pong")
    stub_request(:get, "malomalo.io/tables").to_return(:body => ['ships'].to_json)
    
    stub_request(:get, "malomalo.io/ships/schema").to_return(:body => {
      id: {type: 'integer', primary_key: true, null: false, array: false},
      fleet_id: {type: 'integer', primary_key: false, null: true, array: false},
      name: {type: 'string', primary_key: false, null: true, array: false}
    }.to_json)
    
    stub_request(:get, "malomalo.io/fleets/schema").to_return(:body => {
      id: {type: 'integer', primary_key: true, null: false, array: false},
      name: {type: 'string', primary_key: false, null: true, array: false}
    }.to_json)
    
    stub_request(:get, "malomalo.io/sailors/schema").to_return(:body => {
      id: {type: 'integer', primary_key: true, null: false, array: false},
      name: {type: 'string', primary_key: false, null: true, array: false}
    }.to_json)
    
    ActiveRecord::Base.establish_connection(
      :adapter => 'sunstone',
      :site    => 'http://malomalo.io'
    )
  end
  
  test '::find' do
    stub_request(:get, URI::escape('malomalo.io/ships?limit=1&where[id]=42')).to_return(body: [{id: 42}].to_json)
    
    assert_equal 42, Ship.find(42).id
  end
  
  test '::first' do
    stub_request(:get, URI::escape('malomalo.io/ships?limit=1&order[][id]=asc')).to_return(body: [].to_json)
    
    assert_nil Ship.first
  end
  
  test '::last' do
    stub_request(:get, URI::escape('malomalo.io/ships?limit=1&order[][id]=desc')).to_return(body: [].to_json)
    
    assert_nil Ship.last
  end
  
  test '::find_each' do
    stub_request(:get, URI::escape('malomalo.io/ships?limit=1000&order[][id]=asc')).to_return(body: [].to_json)
    
    assert_nil Ship.find_each { |s| s }
  end
  
  test '::where on columns' do
    stub_request(:get, URI::escape('malomalo.io/ships?where[id]=10')).to_return(body: [].to_json)

    assert_equal [], Ship.where(:id => 10).to_a
  end
  
  test '::where on belongs_to relation' do
    stub_request(:get, URI::escape('malomalo.io/ships?where[fleet][id]=1')).to_return(body: [].to_json)

    assert_equal [], Ship.where(:fleet => {id: 1}).to_a
  end
  
  test '::where on has_many relation' do
    stub_request(:get, URI::escape('malomalo.io/fleets?where[ships][id]=1')).to_return(body: [].to_json)

    assert_equal [], Fleet.where(:ships => {id: 1}).to_a
  end
  
  test '::where on has_and_belongs_to_many relation' do
    stub_request(:get, URI::escape('malomalo.io/ships?where[sailors][id]=1')).to_return(body: [].to_json)
    
    assert_equal [], Ship.where(:sailors => {id: 1}).to_a
  end
  
  test '::count' do
    stub_request(:get, URI::escape('malomalo.io/ships/calculate?select[][count]=*')).to_return(body: '[10]')
    
    assert_equal 10, Ship.count
  end
  
  test '::count(:column)' do
    stub_request(:get, URI::escape('malomalo.io/ships/calculate?select[][count]=id')).to_return(body: '[10]')
    
    assert_equal 10, Ship.count(:id)
  end
  
  test '::sum(:column)' do
    stub_request(:get, URI::escape('malomalo.io/ships/calculate?select[][sum]=weight')).to_return(body: '[10]')
    
    assert_equal 10, Ship.sum(:weight)
  end
  
  # Relation test
  
  test '#to_sql' do
    stub_request(:get, URI::escape('malomalo.io/ships?where[id]=10')).to_return(body: [].to_json)
    
    assert_equal "SELECT ships.* FROM ships WHERE ships.id = 10", Ship.where(:id => 10).to_sql
  end

  # Preload test
  
  test '#preload' do
    stub_request(:get, URI::escape('malomalo.io/fleets')).to_return(body: [{id: 1}].to_json)
    stub_request(:get, URI::escape('malomalo.io/ships?where[fleet_id][0]=1')).to_return(body: [{id: 1, fleet_id: 1}].to_json)
    
    fleets = Fleet.preload(:ships)
    assert_equal [1], fleets.map(&:id)
    assert_equal [1], fleets.first.ships.map(&:id)
  end
  
  # Eagerload test
  
  test '#eager_load' do
    stub_request(:get, URI::escape('malomalo.io/fleets?include[]=ships')).to_return(body: [{
      id: 1, ships: [{id: 1, fleet_id: 1}]
    }].to_json)
    
    fleets = Fleet.eager_load(:ships)
    assert_equal [1], fleets.map(&:id)
    assert_equal [1], fleets.first.ships.map(&:id)
  end
  
end
