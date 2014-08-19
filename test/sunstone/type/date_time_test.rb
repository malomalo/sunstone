require 'test_helper'

class Sunstone::Type::DateTimeTest < Minitest::Test

  test "#type_cast_from_user" do
    type = Sunstone::Type::DateTime.new
    
    assert_equal DateTime.new(2001, 2, 3, 4, 5, 6, '+7'), type.type_cast_from_user('2001-02-03T04:05:06+07:00')
    assert_equal DateTime.new(2001, 2, 3, 4, 5, 6, '+7'), type.type_cast_from_user('20010203T040506+0700')
    assert_equal DateTime.new(2001, 2, 3, 4, 5, 6, '+7'), type.type_cast_from_user('2001-W05-6T04:05:06+07:00')
    assert_equal DateTime.new(2014, 7, 14, 16, 44, 15, '-7'), type.type_cast_from_user("2014-07-14T16:44:15-07:00")
    assert_equal Rational(123,1000), type.type_cast_from_user('2001-02-03T04:05:06.123+07:00').sec_fraction
  end
  
  test "#type_cast_from_json" do
    type = Sunstone::Type::DateTime.new
    
    assert_equal DateTime.new(2001, 2, 3, 4, 5, 6, '+7'), type.type_cast_from_json('2001-02-03T04:05:06+07:00')
    assert_equal DateTime.new(2001, 2, 3, 4, 5, 6, '+7'), type.type_cast_from_json('20010203T040506+0700')
    assert_equal DateTime.new(2001, 2, 3, 4, 5, 6, '+7'), type.type_cast_from_json('2001-W05-6T04:05:06+07:00')
    assert_equal DateTime.new(2014, 7, 14, 16, 44, 15, '-7'), type.type_cast_from_json("2014-07-14T16:44:15-07:00")
    assert_equal Rational(123,1000), type.type_cast_from_json('2001-02-03T04:05:06.123+07:00').sec_fraction
  end

  test "#type_cast_for_json" do
    type = Sunstone::Type::DateTime.new
    
    assert_equal '2001-02-03T04:05:06.000+07:00', type.type_cast_for_json(DateTime.new(2001, 2, 3, 4, 5, 6, '+7'))
  end
  
end