require 'test_helper'

class ActiveRecord::Associations::HasAndBelongsToManyTest < Minitest::Test

  test '#relation_ids' do
    webmock(:get, "/ships", where: {id: 42}, limit: 1).to_return(body: [{id: 42, name: "The Niña"}].to_json)
    webmock(:get, "/sailors", where: {sailors_ships: {ship_id: {eq: 42}}}).to_return(body: [{id: 43, name: "Chris"}].to_json)

    puts Ship.find(42).method(:sailor_ids).source_location
    assert_equal [43], Ship.find(42).sailor_ids
  end

end
