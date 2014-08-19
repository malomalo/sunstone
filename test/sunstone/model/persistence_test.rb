require 'test_helper'

class Sunstone::Model::PersistenceTest < Minitest::Test
  
  class TestModel < Sunstone::Model
    define_schema do
      attribute :name, :string
      integer   :size
      datetime  :timestamp
      datetime  :updated_at, :readonly => true
    end
  end

  def setup
    Sunstone.site = "http://test_api_key@testhost.com"
    @klass = Class.new(Sunstone::Model)
  end
  
  test '#serialize' do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    assert_equal '{"id":null,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":null}', model.serialize
  end
  
  test '#serialize(:only => [KEYS])' do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    assert_equal '{"size":20}', model.serialize(:only => ['size'])
  end
  
  
  
  
  test '#save a new record' do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    stub_request(:post, "http://testhost.com/sunstone_model_persistence_test_test_models")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 200,
      :body => '{"id":20,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')
      
    assert_equal true, model.save
  end
  
  test '#save a new invalid record' do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    stub_request(:post, "http://testhost.com/sunstone_model_persistence_test_test_models")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 400,
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')
      
    assert_equal false, model.save
  end
  
  test "#save a new record updates the model with the response" do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    stub_request(:post, "http://testhost.com/sunstone_model_persistence_test_test_models")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 200,
      :body => '{"id":20,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')

    model.save
    assert_equal 20, model.id
    assert_equal time.iso8601(3), model.updated_at.iso8601(3)
  end
  
  test "#save on an new record will set new_record? is false" do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    stub_request(:post, "http://testhost.com/sunstone_model_persistence_test_test_models")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 200,
      :body => '{"id":20,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')

    model.save
    assert_equal false, model.new_record?
  end
  
  test '#save on a persisted record' do
    time = Time.now
    model = TestModel.new(:id => 13, :size => 20, :timestamp => time)
    model.instance_variable_set(:@new_record, false)
    
    stub_request(:put, "http://testhost.com/sunstone_model_persistence_test_test_models/13")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 200,
      :body => '{"id":13,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')
      
    assert_equal true, model.save
  end
  
  test '#save on a persisted record updates the model with the response' do
    time = Time.now
    model = TestModel.new(:id => 13, :size => 20, :timestamp => time)
    model.instance_variable_set(:@new_record, false)
    
    stub_request(:put, "http://testhost.com/sunstone_model_persistence_test_test_models/13")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 200,
      :body => '{"id":13,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')
      
    model.save
    assert_equal 13, model.id
    assert_equal time.iso8601(3), model.updated_at.iso8601(3)
  end
  
  test '#save! a new record' do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    stub_request(:post, "http://testhost.com/sunstone_model_persistence_test_test_models")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 200,
      :body => '{"id":20,"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')
      
    assert_equal true, model.save!
  end
  
  test '#save! a new invalid record' do
    time = Time.now
    model = TestModel.new(:size => 20, :timestamp => time)
    
    stub_request(:post, "http://testhost.com/sunstone_model_persistence_test_test_models")
    .with(
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '"}')
    .to_return(
      :status => 400,
      :body => '{"name":null,"size":20,"timestamp":"' + time.iso8601(3) + '","updated_at":"' + time.iso8601(3) + '"}')
      
    assert_raises Sunstone::RecordInvalid do
      model.save!
    end
  end
  
  
  test '::find(id)' do
    stub_request(:get, "http://testhost.com/sunstone_model_persistence_test_test_models/324").to_return(:body => '{"size": 40}')
    
    model = TestModel.find('324')
    assert_kind_of TestModel, model
    assert_equal 40, model.size
  end
  
  test '::find(id) with 404' do
    stub_request(:get, "http://testhost.com/sunstone_model_persistence_test_test_models/324").to_return(:status => 404)
    
    assert_raises Sunstone::Exception::NotFound do
      TestModel.find('324')
    end
  end
  
end