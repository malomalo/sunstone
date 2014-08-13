require 'test_helper'

class Sunstone::SchemaTest < Minitest::Test

  test "type methods" do
    schema = Sunstone::Schema.new
    
    schema.boolean(:boolean)
    schema.datetime(:datetime)
    schema.decimal(:decimal)
    schema.integer(:integer)
    schema.string(:string)
    
    {
      :boolean  => Sunstone::Type::Boolean,
      :datetime => Sunstone::Type::DateTime,
      :decimal  => Sunstone::Type::Decimal,
      :integer  => Sunstone::Type::Integer,
      :string   => Sunstone::Type::String
    }.each do |name, klass|
      assert_kind_of  klass, schema[name]
    end
  end
  
end