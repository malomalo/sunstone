require 'test_helper'

class ActiveRecord::OrderTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
      t.integer  "captain_id"
    end

    create_table "captains", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
  end
  
  class Ship < ActiveRecord::Base
    belongs_to :captain
  end

  class Captain < ActiveRecord::Base
    has_one :ship
  end

  test '::order(COLUMN)' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :asc}] }).to_return({
      body: [{id: 42}].to_json
    })

    assert_equal 42, Ship.order(:id).first.id
  end

  test '::order(RELATION)' do
    webmock(:get, "/ships", { include: :captain, order: [{ captain: { name: :asc } }] }).to_return({
      body: [{id: 42, captain_id: 1, captain: { id: 1, name: 'James T. Kirk' } }].to_json
    })

    assert_equal 42, Ship.order({ captain: { name: :asc }}).first.id
  end
  
  # TODO: Uses Arel::Nodes::RandomOrdering from:
  #       https://github.com/malomalo/activerecord-sort
  #       which should probably go into arel-extensions?
  test '::order(:random)'
  
end
