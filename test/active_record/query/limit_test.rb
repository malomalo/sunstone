require 'test_helper'

class ActiveRecord::LimitTest < ActiveSupport::TestCase
  schema do
    create_table "ships" do |t|
      t.string   "name",                limit: 255
    end
  end

  class Ship < ActiveRecord::Base
  end
    
  test '::limit' do
    webmock(:get, "/ships", {limit: 5000}).to_return(body: [{id: 42}].to_json)
    assert_equal Ship.limit(5000).map(&:id), [42]
  end


end
