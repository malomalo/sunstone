require 'test_helper'

class Sunstone::Connection::ColumnDefinitionTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",          limit: 255
      t.integer  "guns",          limit: 8
      t.integer  "sailor_count"
    end
  end

  class Ship < ActiveRecord::Base
  end

  test "default limit on column" do
    assert_nil Ship.columns_hash['sailor_count'].limit
  end

  test "custom limit on column" do
    assert_equal 8, Ship.columns_hash['guns'].limit
  end

  test "custom limit on string column" do
    assert_equal 255, Ship.columns_hash['name'].limit
  end
  
end


