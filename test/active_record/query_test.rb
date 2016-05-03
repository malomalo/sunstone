require 'test_helper'

class ActiveRecord::QueryTest < Minitest::Test

  test '::find' do
    webmock(:get, "/ships", { where: {id: 42}, limit: 1 }).to_return(body: [{id: 42}].to_json)
    
    assert_equal 42, Ship.find(42).id
  end
  
  test '::first' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :asc}] }).to_return(body: [].to_json)
    
    assert_nil Ship.first
  end
  
  test '::last' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :desc}] }).to_return(body: [].to_json)
    
    assert_nil Ship.last
  end
  
  test '::find_each' do
    webmock(:get, "/ships", { limit: 1000, order: [{id: :asc}] }).to_return(body: [].to_json)
    
    assert_nil Ship.find_each { |s| s }
  end
  
  test '::where on columns' do
    webmock(:get, "/ships", { where: {id: 10} }).to_return(body: [].to_json)
    
    assert_equal [], Ship.where(:id => 10).to_a
  end
  
  test '::where column is nil' do
    webmock(:get, "/ships", { where: {leased_at: nil} }).to_return(body: [].to_json)

    assert_equal [], Ship.where(:leased_at => nil).to_a
  end
  
  test '::where on belongs_to relation' do
    webmock(:get, "/ships", where: {fleet: { id: {eq: 1} } }).to_return(body: [].to_json)

    assert_equal [], Ship.where(:fleet => {id: 1}).to_a
  end
  
  test '::where on has_many relation' do
    webmock(:get, "/fleets", where: {ships: { id: {eq: 1} } }).to_return(body: [].to_json)

    assert_equal [], Fleet.where(:ships => {id: 1}).to_a
  end
  
  test '::where on has_and_belongs_to_many relation' do
    webmock(:get, "/ships", where: {sailors: { id: {eq: 1} } }).to_return(body: [].to_json)

    assert_equal [], Ship.where(:sailors => {id: 1}).to_a
  end
  
  test '::count' do
    webmock(:get, "/ships/calculate", select: [{count: "*"}]).to_return(body: [10].to_json)
    
    assert_equal 10, Ship.count
  end
  
  test '::count(:column)' do
    webmock(:get, "/ships/calculate", select: [{count: "id"}]).to_return(body: [10].to_json)
    
    assert_equal 10, Ship.count(:id)
  end
  
  test '::sum(:column)' do
    webmock(:get, "/ships/calculate", select: [{sum: "weight"}]).to_return(body: [10].to_json)
    
    assert_equal 10, Ship.sum(:weight)
  end
  
  # Relation test
  
  test '#to_sql' do
    assert_equal "SELECT ships.* FROM ships WHERE ships.id = 10", Ship.where(:id => 10).to_sql
  end
  
end