require 'test_helper'

class ActiveRecord::Associations::HasAndBelongsToManyTest < ActiveSupport::TestCase

  schema do
    create_table "ships" do |t|
      t.string   "name",                    limit: 255
    end

    create_table "sailors" do |t|
      t.string   "name",                    limit: 255
    end

    create_table "sailors_ships", id: false do |t|
      t.integer  "ship_id",                 null: false
      t.integer  "sailor_id",               null: false
    end
  end
  
  class Ship < ActiveRecord::Base
    has_and_belongs_to_many :sailors
  end

  class Sailor < ActiveRecord::Base
    has_and_belongs_to_many :ships
  end

  test '#relation_ids' do
    webmock(:get, "/ships", where: {id: 42}, limit: 1).to_return(body: [{id: 42, name: "The Niña"}].to_json)
    webmock(:get, "/sailors", where: {sailors_ships: {ship_id: {eq: 42}}}).to_return(body: [{id: 43, name: "Chris"}].to_json)

    assert_equal [43], Ship.find(42).sailor_ids
  end

end
