require 'test_helper'

class ActiveRecord::OrderTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
  end
  
  class Ship < ActiveRecord::Base
  end

  test '::order(COLUMN)' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :asc}] }).to_return({
      body: [{id: 42}].to_json
    })

    assert_equal 42, Ship.order(:id).first.id
  end
  
  # TODO: Uses Arel::Nodes::RandomOrdering from:
  #       https://github.com/malomalo/activerecord-sort
  #       which should probably go into arel-extensions?
  test '::order(:random)'
  
end
