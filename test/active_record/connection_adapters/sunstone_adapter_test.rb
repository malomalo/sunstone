require 'test_helper'

class ActiveRecord::ConnectionAdapters::SunstoneAdapterTest < ActiveSupport::TestCase

  schema do
    create_table "ships", limit: 100 do |t|
      t.string   "name",                    limit: 255
    end
  end

  class Ship < ActiveRecord::Base
    rpc :self_destruct
  end
  
  test '::rpc calls custom controller function' do
    webmock(:get, "/ships", { limit: 1, order: [{id: :asc}] }).to_return({
      body: [{id: 3, name: 'Sivar'}].to_json
    })

    webmock(:post, '/ships/3/self_destruct').to_return({
      body: {name: 'DESTROYED'}.to_json
    })

    ship = Ship.first
    assert ship.self_destruct!
    assert_equal 'DESTROYED', ship.name
    assert ship.changes.empty?
  end

end