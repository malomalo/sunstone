require 'test_helper'

class ActiveRecord::QueryDistinctTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
  end
  
  class Ship < ActiveRecord::Base
  end

  # Distinct
  test '::distinct query' do
    webmock(:get, "/ships", distinct: true, limit: 100, offset: 0).to_return({
      body: [].to_json
    })

    assert_equal [], Ship.distinct
  end

  # TODO: i need arel-extensions....
  # test '::distinct_on query' do
  #   webmock(:get, "/ships", distinct_on: ['id']).to_return(body: [].to_json)
  #
  #   assert_equal [], Ship.distinct_on(:id)
  # end

end
