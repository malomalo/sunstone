require 'test_helper'

class Sunstone::Type::DecimalTest < Minitest::Test

  test "#type_cast_from_user" do
    type = Sunstone::Type::Decimal.new
    
    assert_equal BigDecimal.new("10.50"), type.type_cast_from_user(BigDecimal.new("10.50"))
    assert_equal BigDecimal.new("10.50"), type.type_cast_from_user(10.50)
    assert_equal BigDecimal.new("10.50"), type.type_cast_from_user("10.50")
  end
  
  test "#type_cast_from_json" do
    type = Sunstone::Type::Decimal.new
    
    assert_equal BigDecimal.new("10.50"), type.type_cast_from_json(BigDecimal.new("10.50"))
    assert_equal BigDecimal.new("10.50"), type.type_cast_from_json(10.50)
    assert_equal BigDecimal.new("10.50"), type.type_cast_from_json("10.50")
  end
  
  test "#type_cast_for_json" do
    type = Sunstone::Type::Decimal.new
    
    assert_equal BigDecimal.new("10.50"), type.type_cast_for_json(BigDecimal.new("10.50"))
  end

end