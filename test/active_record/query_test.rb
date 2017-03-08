require 'test_helper'

class ActiveRecord::QueryTest < ActiveSupport::TestCase

  test '::find w/ old schema definition' do
    replaced_stub = WebMock::StubRegistry.instance.global_stubs.find { |x|
      x.request_pattern.uri_pattern.to_s == 'http://example.com/ships/schema'
    }
    WebMock::StubRegistry.instance.global_stubs.delete(replaced_stub)

    new_stub = WebMock::API.stub_request(:get, "http://example.com/ships/schema").to_return(
      body: {
        id: {type: 'integer', primary_key: true, null: false, array: false},
        fleet_id: {type: 'integer', primary_key: false, null: true, array: false},
        name: {type: 'string', primary_key: false, null: true, array: false}
      }.to_json
    )

    webmock(:get, "/ships", { where: {id: 42}, limit: 1 }).to_return(body: [{id: 42}].to_json)

    assert_equal 42, Ship.find(42).id

    WebMock::API.remove_request_stub(new_stub)
    WebMock::StubRegistry.instance.global_stubs.push(replaced_stub)
  end

  test '::find' do
    webmock(:get, "/ships", { where: {id: 42}, limit: 1 }).to_return(body: [{id: 42}].to_json)

    assert_equal 42, Ship.find(42).id
  end

  test '::first' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :asc}] }).to_return(body: [].to_json)

    assert_nil Ship.first
  end

  test '::last' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :desc}] }).to_return(body: [].to_json)

    assert_nil Ship.last
  end

  test '::find_each' do
    webmock(:get, "/ships", { limit: 100, offset: 0, order: [{id: :asc}] }).to_return(body: Array.new(100, { id:  1 }).to_json)
    webmock(:get, "/ships", { limit: 100, offset: 100, order: [{id: :asc}] }).to_return(body: Array.new(10, { id: 2 }).to_json)

    assert_nil Ship.find_each { |s| s }
  end

  test '::where on columns' do
    webmock(:get, "/ships", { where: { id: 10 }, limit: 100, offset: 0 }).to_return(body: [].to_json)

    assert_equal [], Ship.where(:id => 10).to_a
  end

  test '::where column is nil' do
    webmock(:get, "/ships", { where: { leased_at: nil }, limit: 100, offset: 0 }).to_return(body: [].to_json)

    assert_equal [], Ship.where(:leased_at => nil).to_a
  end

  test '::where on belongs_to relation' do
    webmock(:get, "/ships", where: {fleet: { id: {eq: 1} } }, limit: 100, offset: 0).to_return(body: [].to_json)

    assert_equal [], Ship.where(:fleet => {id: 1}).to_a
  end

  test '::where on has_many relation' do
    webmock(:get, "/fleets", where: {ships: { id: {eq: 1} } }).to_return(body: [].to_json)

    assert_equal [], Fleet.where(:ships => {id: 1}).to_a
  end

  test '::where on has_and_belongs_to_many relation' do
    webmock(:get, "/ships", where: {sailors: { id: {eq: 1} } }, limit: 100, offset: 0).to_return(body: [].to_json)

    assert_equal [], Ship.where(:sailors => {id: 1}).to_a
  end

  # Polymorphic
  test '::where on a has_many throught a polymorphic source' do
    webmock(:get, "/ships", where: { nations: { id: {eq: 1} } }, limit: 10).to_return(body: [].to_json)

    assert_equal [], Ship.where(nations: {id: 1}).limit(10).to_a
  end
  ### end polymorphic test

  # Distinct
  test '::distinct query' do
    webmock(:get, "/ships", distinct: true, limit: 100, offset: 0).to_return(body: [].to_json)

    assert_equal [], Ship.distinct
  end

  # TODO: i need arel-extensions....
  # test '::distinct_on query' do
  #   webmock(:get, "/ships", distinct_on: ['id']).to_return(body: [].to_json)
  #
  #   assert_equal [], Ship.distinct_on(:id)
  # end

  test '::count' do
    webmock(:get, "/ships/calculate", select: [{count: "*"}], limit: 100, offset: 0).to_return(body: [10].to_json)

    assert_equal 10, Ship.count
  end

  test '::count(:column)' do
    webmock(:get, "/ships/calculate", select: [{count: "id"}], limit: 100, offset: 0).to_return(body: [10].to_json)

    assert_equal 10, Ship.count(:id)
  end

  test '::sum(:column)' do
    webmock(:get, "/ships/calculate", select: [{sum: "weight"}], limit: 100, offset: 0).to_return(body: [10].to_json)

    assert_equal 10, Ship.sum(:weight)
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
    assert_equal 'SELECT ships.* FROM ships INNER JOIN ownerships ON ownerships.asset_id = ships.id AND ownerships.asset_type = \'Ship\' WHERE ownerships.id = 1', Ship.joins(:ownerships).where({ ownerships: { id: 1 } }).to_sql
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