require 'test_helper'

class ActiveRecord::QueryAllTest < ActiveSupport::TestCase
  schema do
    create_table "ships" do |t|
      t.string   "name",                    limit: 255
    end
    
    create_table "cars", limit: 100 do |t|
      t.string   "name",                limit: 255
    end
  end

  class Ship < ActiveRecord::Base
  end

  class Car < ActiveRecord::Base
  end
    
  test '::all' do
    webmock(:get, "/ships").to_return(body: [{id: 42}].to_json)
    assert_equal [Ship.new(id: 42)], Ship.all
  end

  test '::all w/resource_limit' do
    cars = []
    101.times { |i| cars << Car.new(id: i) }
    webmock(:get, "/cars", { limit: 100, offset: 0 }).to_return(body: cars[0..100].to_json)
    webmock(:get, "/cars", { limit: 100, offset: 100 }).to_return(body: cars[101..-1].to_json)
    assert_equal cars, Car.all
  end

end
