require 'test_helper'

class Sunstone::Model::AttributesTest < Minitest::Test

  def setup
    @klass = Class.new(Sunstone::Model)
  end
  
  test "inherited models get a schema setup with id" do
    assert_kind_of Sunstone::Schema,        @klass.schema
    assert_kind_of Sunstone::Type::Integer, @klass.schema[:id]
  end
  
  test "::attribute" do
    @klass.attribute :name, :string
    
    assert_kind_of Sunstone::Type::String, @klass.schema[:name]
  end

  test "::attribute sets up readers" do
    @klass.attribute :name, :string
    model = @klass.new
    
    model.attributes[:name] = "my name"
    assert_equal "my name", model.name
  end
  
  test "::attributes sets up writer" do
    @klass.attribute :name, :string
    model = @klass.new
    
    model.schema[:name].expects(:type_cast_from_user).with("my name").returns("value")
    model.name = "my name"
    
    assert_equal "value", model.name
    assert_equal "value", model.attributes[:name]
  end
  
  test "::define_schema" do
    @klass.define_schema do
      attribute :name, :string
      integer   :size
    end
    
    assert_kind_of Sunstone::Type::String,  @klass.schema[:name]
    assert_kind_of Sunstone::Type::Integer, @klass.schema[:size]
  end
  
end