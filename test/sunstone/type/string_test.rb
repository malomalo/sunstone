require 'test_helper'

class Sunstone::Type::StringTest < Minitest::Test

  test "#type_cast_from_user" do
    type = Sunstone::Type::String.new
    
    assert_equal "1",       type.type_cast_from_user(true)
    assert_equal "0",       type.type_cast_from_user(false)
    assert_equal "123",     type.type_cast_from_user(123)
    assert_equal "string",  type.type_cast_from_user("string")
  end
  
  test "#type_cast_from_json" do
    type = Sunstone::Type::String.new
    
    assert_equal "1",       type.type_cast_from_json(true)
    assert_equal "0",       type.type_cast_from_json(false)
    assert_equal "123",     type.type_cast_from_json(123)
    assert_equal "string",  type.type_cast_from_json("string")
  end
  
  test "#type_cast_for_json" do
    type = Sunstone::Type::String.new
    
    assert_equal "10", type.type_cast_for_json("10")
  end
  
  test "values are duped coming out" do
    s = "foo"
    type = Sunstone::Type::String.new
    
    assert_not_same s, type.type_cast_from_user(s)
    assert_not_same s, type.type_cast_from_json(s)
  end

  test "string mutations are detected" # do
  #   klass = Class.new(Model)
  #   klass.table_name = 'authors'
  #
  #   author = klass.create!(name: 'Sean')
  #   assert_not author.changed?
  #
  #   author.name << ' Griffin'
  #   assert author.name_changed?
  #
  #   author.save!
  #   author.reload
  #
  #   assert_equal 'Sean Griffin', author.name
  #   assert_not author.changed?
  # end
  
end