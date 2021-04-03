require 'test_helper'

class ActiveRecord::LimitTest < ActiveSupport::TestCase
  schema do
    create_table "ships" do |t|
      t.string   "name",                limit: 255
    end

    create_table "sailors" do |t|
      t.string   "name",                limit: 255
      t.integer  "ship_id",             null: false
    end

    create_table "arms" do |t|
      t.string   "name",                limit: 255
      t.integer  "sailor_id",             null: false
    end
  end

  class Ship < ActiveRecord::Base
    has_many :crew, class_name: "Sailor"
  end

  class Arm < ActiveRecord::Base
    belongs_to :sailor
  end

  class Sailor < ActiveRecord::Base
    belongs_to :ship
    has_many :arms
  end

  test '::limit' do
    webmock(:get, "/ships", {limit: 5000}).to_return(body: [{id: 42}].to_json)
    assert_equal Ship.limit(5000).map(&:id), [42]
  end

  test '::limit with eager loading  and joining' do
    webmock(:get, "/sailors", { include: ['ship'], limit: 8 }).to_return(body: [{id: 42}].to_json)
    assert_equal Sailor.eager_load(:ship).joins(:arms).limit(8).map(&:id), [42]
  end

  test '::offset with eager loading'

end
