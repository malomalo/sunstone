require 'test_helper'

class ActiveRecord::QueryCountTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
  end
  
  class Ship < ActiveRecord::Base
  end

  test '::count' do
    webmock(:get, "/ships/calculate", select: [{count: "*"}], limit: 100, offset: 0).to_return({
      body: [10].to_json
    })

    assert_equal 10, Ship.count
  end

  test '::count(:column)' do
    webmock(:get, "/ships/calculate", select: [{count: "id"}], limit: 100, offset: 0).to_return({
      body: [10].to_json
    })

    assert_equal 10, Ship.count(:id)
  end

  test '::sum(:column)' do
    webmock(:get, "/ships/calculate", select: [{sum: "weight"}], limit: 100, offset: 0).to_return({
      body: [10].to_json
    })

    assert_equal 10, Ship.sum(:weight)
  end

end
