require 'test_helper'

class ActiveRecord::QueryWhereTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
    
    create_table "fleets" do |t|
      t.string   "name",                    limit: 255
      t.integer  "fleet_id"
    end
  end

  class Fleet < ActiveRecord::Base
    has_many :ships
  end
  
  class Ship < ActiveRecord::Base
    belongs_to :fleet
  end

  test '::where on columns' do
    webmock(:get, "/ships", { where: { id: 10 }, limit: 100, offset: 0 }).to_return(body: [].to_json)

    assert_equal [], Ship.where(id: 10).to_a
  end

  test '::where column is nil' do
    webmock(:get, "/ships", { where: { fleet_id: nil }, limit: 100, offset: 0 }).to_return(body: [].to_json)

    assert_equal [], Ship.where(fleet_id: nil).to_a
  end

  test '::where on belongs_to relation' do
    webmock(:get, "/ships", where: {fleet: { id: {eq: 1} } }, limit: 100, offset: 0).to_return(body: [].to_json)

    assert_equal [], Ship.where(fleet: {id: 1}).to_a
  end

  test '::where on has_many relation' do
    webmock(:get, "/fleets", where: {ships: { id: {eq: 1} } }).to_return(body: [].to_json)

    assert_equal [], Fleet.where(ships: {id: 1}).to_a
  end

  test '::where on has_and_belongs_to_many relation' do
    webmock(:get, "/ships", where: {sailors: { id: {eq: 1} } }, limit: 100, offset: 0).to_return(body: [].to_json)

    assert_equal [], Ship.where(sailors: {id: 1}).to_a
  end

  # Polymorphic
  test '::where on a has_many throught a polymorphic source' do
    webmock(:get, "/ships", where: { nations: { id: {eq: 1} } }, limit: 10).to_return(body: [].to_json)

    assert_equal [], Ship.where(nations: {id: 1}).limit(10).to_a
  end
  ### end polymorphic test
  

end
