require 'test_helper'

class TestModel < Sunstone::Model
  
  belongs_to :test_model
  
  has_many :test_models
  
  define_schema do
    integer   :testid
    boolean   :red
    datetime  :created_at
    decimal   :rate
    string    :name
    string    :nicknames, :array => true
  end
end

class Sunstone::ParserTest < Minitest::Test

  test '::parse(klass, string)' do
    assert_equal true, Sunstone::Parser.parse(TestModel, '{"red": true}').red
  end
  
  test '::parse(klass, response)' do
    Sunstone.site = "http://test_api_key@testhost.com"
    stub_request(:get, "http://testhost.com/test").to_return(:body => '{"red": true}')
    
    model = Sunstone.get('/test') do |response|
      Sunstone::Parser.parse(TestModel, response)
    end
    
    assert_equal true, model.red
  end
  
  test "parse boolean attributes" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal true, parser.parse('{"red": true}').red

    parser = Sunstone::Parser.new(TestModel)
    assert_equal false, parser.parse('{"red": false}').red
  end

  test "parse date attributes" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal DateTime.new(2014, 7, 14, 16, 44, 15, '-7'), parser.parse('{"created_at": "2014-07-14T16:44:15-07:00"}').created_at
  end

  test "parse decimal attributes" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal 10.254, parser.parse('{"rate": 10.254}').rate
  end
  
  test "parse integer attributes" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal 123654, parser.parse('{"testid": 123654}').testid
  end
  
  test "parse string attributes" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal "my name", parser.parse('{"name": "my name"}').name
  end

  test "parse array attribute" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal ["name 1", "name 2"], parser.parse('{"nicknames": ["name 1", "name 2"]}').nicknames
  end
  
  test "parse skips over unkown key" do
    assert_nothing_raised do
      Sunstone::Parser.parse(TestModel, '{"other_key": "name 2"}')
      Sunstone::Parser.parse(TestModel, '{"other_key": ["name 1", "name 2"]}')
    end
  end
  
  test "parse belong_to association" do
    parser = Sunstone::Parser.new(TestModel)
    assert_equal({
      :rate => BigDecimal.new("10.254"),
      :created_at => DateTime.new(2014, 7, 14, 16, 44, 15, '-7'),
      :testid => 123654,
      :name => "my name",
      :nicknames => ["name 1", "name 2"]
    }, parser.parse('{"test_model": {
      "rate": 10.254,
      "created_at": "2014-07-14T16:44:15-07:00",
      "testid": 123654,
      "name": "my name",
      "nicknames": ["name 1", "name 2"]
    }}').test_model.instance_variable_get(:@attributes))
  end
  
  test "parse has_many association" do
    parser = Sunstone::Parser.new(TestModel)
    attrs = {
      :rate => BigDecimal.new("10.254"),
      :created_at => DateTime.new(2014, 7, 14, 16, 44, 15, '-7'),
      :testid => 123654,
      :name => "my name",
      :nicknames => ["name 1", "name 2"]
    }
    
    assert_equal([attrs, attrs], parser.parse('{"test_models": [{
      "rate": 10.254,
      "created_at": "2014-07-14T16:44:15-07:00",
      "testid": 123654,
      "name": "my name",
      "nicknames": ["name 1", "name 2"]
    }, {
      "rate": 10.254,
      "created_at": "2014-07-14T16:44:15-07:00",
      "testid": 123654,
      "name": "my name",
      "nicknames": ["name 1", "name 2"]
    }]}').test_models.map{|m| m.instance_variable_get(:@attributes)})
  end
  
end