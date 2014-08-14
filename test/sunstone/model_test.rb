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


class Sunstone::ModelTest < Minitest::Test

  def setup
    Sunstone.site = "http://test_api_key@testhost.com"
  end
  
  #TODO: test initializer
  
  test '::find(id)' do
    stub_request(:get, "http://testhost.com/test_models/324").to_return(:body => '{"red": true}')
    
    model = TestModel.find('324')
    assert_kind_of TestModel, model
    assert_equal true, model.red
  end
  
  test '::find(id) with 404' do
    stub_request(:get, "http://testhost.com/test_models/324").to_return(:status => 404, :body => '{"red": true}')
    
    assert_raises Sunstone::Exception::NotFound do
      TestModel.find('324')
    end
  end
  
end