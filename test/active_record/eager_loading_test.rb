require 'test_helper'

class ActiveRecord::EagerLoadingTest < Minitest::Test

  test '#eager_load' do
    webmock(:get, "/fleets", include: [{:ships => :sailors}]).to_return(body: [{
      id: 1, ships: [{id: 1, fleet_id: 1}]
    }].to_json)
    
    fleets = Fleet.eager_load(:ships => :sailors)
    assert_equal [1], fleets.map(&:id)
    assert_equal [1], fleets.first.ships.map(&:id)
  end
  
end
