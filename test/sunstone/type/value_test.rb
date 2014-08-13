require 'test_helper'

class Sunstone::Type::ValueTest < Minitest::Test

  test "array support" do
    type = Sunstone::Type::Value.new(:array => true)
    
    type.expects(:_type_cast).with(1).returns(1).twice
    type.expects(:_type_cast).with('2').returns('2').twice
    type.expects(:_type_cast).with(:a).returns(:a).twice
    
    assert_equal([1, '2', :a], type.type_cast_from_user([1, '2', :a]))
    assert_equal([1, '2', :a], type.type_cast_from_json([1, '2', :a]))
  end
  
end