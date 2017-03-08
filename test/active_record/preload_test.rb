require 'test_helper'

class ActiveRecord::PreloadTest < ActiveSupport::TestCase
  
  test '#preload' do
    webmock(:get, "/fleets").to_return(body: [{id: 1}].to_json)
    webmock(:get, "/ships", where: {fleet_id: 1}, limit: 100, offset: 0).to_return(body: [{id: 1, fleet_id: 1}].to_json)
    webmock(:get, "/sailors_ships", where: {ship_id: 1}, limit: 100, offset: 0).to_return(body: [{ship_id: 1, sailor_id: 1}].to_json)
    webmock(:get, "/sailors", where: {id: 1}, limit: 100, offset: 0).to_return(body: [{id: 1}].to_json)
    
    fleets = Fleet.preload(:ships => :sailors)
    assert_equal [1], fleets.map(&:id)
    assert_equal [1], fleets.first.ships.map(&:id)
  end
  
end
