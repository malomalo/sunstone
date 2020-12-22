require 'test_helper'

class Sunstone::Connection::RequestHelpersTest < ActiveSupport::TestCase

  # Sunstone.get ==============================================================

  test '#get(path)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(:body => "get")

    assert_equal('get', connection.get('/test').body)
  end

  test '#get(path, params) with params as string' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").with(:query => {'key' => 'value'}).to_return(:body => "get")

    assert_equal 'get', connection.get('/test', 'key=value').body
  end

  test '#get(path, params) with params as hash' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").with(:query => {'key' => 'value'}).to_return(:body => "get")

    assert_equal 'get', connection.get('/test', {:key => 'value'}).body
  end

  test '#get(path, &block)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')

    connection.get('/test') do |response|
      assert_equal 'get', response.body
    end
  end

  # Sunstone.post =============================================================

  test '#post(path)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:post, "http://testhost.com/test").to_return(:body => "post")

    assert_equal('post', connection.post('/test').body)
  end

  test '#post(path, body)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:post, "http://testhost.com/test").with(:body => 'body').to_return(:body => "post")

    assert_equal('post', connection.post('/test', 'body').body)
  end

  test '#post(path, &block)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:post, "http://testhost.com/test").to_return(:body => 'post')

    connection.post('/test') do |response|
      assert_equal 'post', response.body
    end
  end

  # Sunstone.put ==============================================================

  test '#put(path)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:put, "http://testhost.com/test").to_return(:body => "put")

    assert_equal('put', connection.put('/test').body)
  end

  test '#put(path, body)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:put, "http://testhost.com/test").with(:body => 'body').to_return(:body => "put")

    assert_equal('put', connection.put('/test', 'body').body)
  end

  test '#put(path, &block)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:put, "http://testhost.com/test").to_return(:body => 'put')

    connection.put('/test') do |response|
      assert_equal 'put', response.body
    end
  end

  # Sunstone.delete ===========================================================

  test '#delete' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:delete, "http://testhost.com/test").to_return(:body => "delete")

    assert_equal('delete', connection.delete('/test').body)
  end

  test '#delete(path, &block)' do
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:delete, "http://testhost.com/test").to_return(:body => 'delete')

    connection.delete('/test') do |response|
      assert_equal 'delete', response.body
    end
  end

end