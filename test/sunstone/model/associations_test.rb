require 'test_helper'

class BelongsToModel < Sunstone::Model
end


class Sunstone::Model::AssociationsTest < Minitest::Test

  def setup
    @klass = Class.new(Sunstone::Model)
  end
  
  test "inherited models get a schema setup with id" do
    assert_equal({},        @klass.reflect_on_associations)
  end
  
  test "::belongs_to adds association" do
    @klass.belongs_to :belongs_to_model
    
    assert_equal({
      :name=>:belongs_to_model,
      :macro=>:belongs_to,
      :klass=>BelongsToModel,
      :foreign_key=>:belongs_to_model_id
    }, @klass.reflect_on_associations[:belongs_to_model])
  end
  
  test "::belongs_to addes foreign_key attribute to class" do
    @klass.belongs_to :belongs_to_model
    
    assert_kind_of Sunstone::Type::Integer, @klass.schema[:belongs_to_model_id]
  end
  
  test "::belongs_to setter and getter" do
    @klass.belongs_to :belongs_to_model
    
    model = @klass.new
    omodel = BelongsToModel.new(:id => 10)
    assert_nil model.belongs_to_model
    model.belongs_to_model = omodel
    assert_equal omodel, model.belongs_to_model
    assert_equal 10, model.belongs_to_model_id
  end
  
  test "::has_many adds association" do
    @klass.has_many :belongs_to_models
    
    assert_equal({
      :name         => :belongs_to_models,
      :macro        => :has_many,
      :klass        => BelongsToModel
    }, @klass.reflect_on_associations[:belongs_to_models])
  end

end