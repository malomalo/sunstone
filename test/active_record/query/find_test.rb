require 'test_helper'

class ActiveRecord::QueryFindTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
  end
  
  class Ship < ActiveRecord::Base
  end

  test '::find' do
    webmock(:get, "/ships", { where: {id: 42}, limit: 1 }).to_return({
      body: [{id: 42}].to_json
    })

    assert_equal 42, Ship.find(42).id
  end

  test '::find_each' do
    requests = []
    
    requests << webmock(:get, "/ships", { limit: 100, offset: 0, order: [{id: :asc}] }).to_return({
      body: Array.new(100, { id: 1 }).to_json
    })
    requests << webmock(:get, "/ships", { limit: 100, offset: 100, order: [{id: :asc}] }).to_return({
      body: Array.new(10, { id: 2 }).to_json
    })
    
    assert_nil Ship.find_each { |s| s }
    
    requests.each { |r| assert_requested(r) }
  end
  
end
