require 'test_helper'

class ActiveRecord::QueryTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
    
    create_table "ownerships" do |t|
      t.string  "asset_type"
      t.integer  "asset_id"
    end
  end

  class Ship < ActiveRecord::Base
    has_many :ownerships, as: :asset
  end
  
  class Ownership < ActiveRecord::Base
    belongs_to :asset, polymorphic: true
  end
  
  test '::first' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :asc}] }).to_return({
      body: [].to_json
    })

    assert_nil Ship.first
  end

  test '::last' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :desc}] }).to_return({
      body: [].to_json
    })

    assert_nil Ship.last
  end
  
  test '::where(AND CONDITION)' do
    webmock(:get, "/ships", { where: {id: 10, name: 'name'}, limit: 1, order: [{id: :asc}] }).to_return({
      body: [{id: 42}].to_json
    })
    puts unpack('%83%A5where%80%A5limit%01%A5order%91%81%A2id%A3asc')
    arel_table = Ship.arel_table
    assert_equal 42, Ship.where(arel_table[:id].eq(10).and(arel_table[:name].eq('name'))).first.id
  end
  
  test '::where(OR CONDITION)' do
    webmock(:get, "/ships", { where: [{id: 10}, 'OR', {name: 'name'}], limit: 1, order: [{id: :asc}] }).to_return({
      body: [{id: 42}].to_json
    })

    arel_table = Ship.arel_table
    assert_equal 42, Ship.where(arel_table[:id].eq(10).or(arel_table[:name].eq('name'))).first.id
  end

  test '::where(AND & OR CONDITION)' do
    webmock(:get, "/ships", { where: [{id: 10}, 'AND', [{id: 10}, 'OR', {name: 'name'}]], limit: 1, order: [{id: :asc}] }).to_return({
      body: [{id: 42}].to_json
    })

    arel_table = Ship.arel_table
    assert_equal 42, Ship.where(arel_table[:id].eq(10).and(arel_table[:id].eq(10).or(arel_table[:name].eq('name')))).first.id
  end

  test '::where(....big get request turns into post...)' do
    name = 'q' * 3000
    webmock(:post, "/ships").with(
      headers: {'X-Http-Method-Override' => 'GET'},
      body: {where: { name: name }, limit: 100, offset: 0 }.to_json
    ).to_return(body: [{id: 42}].to_json)

    assert_equal 42, Ship.where(name: name)[0].id
  end

  # Relation test

  test '#to_sql' do
    assert_equal "SELECT ships.* FROM ships WHERE ships.id = 10", Ship.where(:id => 10).to_sql
  end

  test '#to_sql binds correctly when joining' do
    assert_equal 'SELECT ships.* FROM ships INNER JOIN ownerships ON ownerships.asset_id = ships.id AND ownerships.asset_type = \'ActiveRecord::QueryTest::Ship\' WHERE ownerships.id = 1', Ship.joins(:ownerships).where({ ownerships: { id: 1 } }).to_sql
  end

  test '#to_sar' do
    assert_equal "/ships?%81%A5where%81%A2id%A210", Ship.where(:id => 10).to_sar.path
  end

  test 'bind params get eaten when joining' do
    uri = URI(Ship.joins(:ownerships).where({ ownerships: { id: 1 } }).to_sar.path)
    query = MessagePack.unpack(CGI.unescape(uri.query))
    assert_equal({"where"=>{"ownerships"=>{"id"=>{"eq"=>"1"}}}}, query)
  end

end