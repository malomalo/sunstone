require 'test_helper'

class Sunstone::Type::ValueTest < Minitest::Test

  test "#readonly?" do
    type = Sunstone::Type::Value.new(:readonly => true)
    assert_equal true, type.readonly?
  end
  
  test "array support" do
    type = Sunstone::Type::Value.new(:array => true)
    
    type.expects(:_type_cast).with(1).returns(1).twice
    type.expects(:_type_cast).with('2').returns('2').twice
    type.expects(:_type_cast).with(:a).returns(:a).twice
    
    assert_equal([1, '2', :a], type.type_cast_from_user([1, '2', :a]))
    assert_equal([1, '2', :a], type.type_cast_from_json([1, '2', :a]))
  end
  
  test "#type_cast_for_json" do
    type = Sunstone::Type::Value.new(:array => true)
    
    assert_equal [1, '2', :a], type.type_cast_for_json([1, '2', :a])
  end
  
end