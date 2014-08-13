require 'test_helper'

class Sunstone::Type::IntegerTest < Minitest::Test

  test "#type_cast_from_user" do
    type = Sunstone::Type::Integer.new
    
    assert_equal 10, type.type_cast_from_user(10)
    assert_equal 10, type.type_cast_from_user("10")
    assert_equal 1,  type.type_cast_from_user(true)
    assert_equal 0,  type.type_cast_from_user(false)
  end
  
  test "#type_cast_from_json" do
    type = Sunstone::Type::Integer.new
    
    assert_equal 10, type.type_cast_from_json(10)
    assert_equal 10, type.type_cast_from_json("10")
    assert_equal 1,  type.type_cast_from_json(true)
    assert_equal 0,  type.type_cast_from_json(false)
  end

end