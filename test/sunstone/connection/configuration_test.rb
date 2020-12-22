require 'test_helper'

class Sunstone::Connection::ConfigurationTest < ActiveSupport::TestCase

  test "setting the endpoint sets the api_key" do
    connection = Sunstone::Connection.new(endpoint: 'http://my_api_key@localhost')
    assert_equal('my_api_key', connection.api_key)
  end

  test "setting the endpoint sets the host" do
    connection = Sunstone::Connection.new(endpoint: 'https://example.com')
    assert_equal('example.com', connection.host)
  end

  test "setting the endpoint sets the port" do
    connection = Sunstone::Connection.new(endpoint: 'http://localhost')
    assert_equal(80, connection.port)

    connection = Sunstone::Connection.new(endpoint: 'https://localhost')
    assert_equal(443, connection.port)
    
    connection = Sunstone::Connection.new(endpoint: 'https://localhost:4321')
    assert_equal(4321, connection.port)
  end

  test "setting the endpoint sets the use_ssl option" do
    connection = Sunstone::Connection.new(endpoint: 'http://localhost')
    assert_equal(false, connection.use_ssl)
    
    connection = Sunstone::Connection.new(endpoint: 'https://localhost')
    assert_equal(true, connection.use_ssl)
  end
  
  test "setting the user_agent appends it to the User-Agent" do
    connection = Sunstone::Connection.new(endpoint: 'http://localhost')
    assert_equal("Sunstone/#{Sunstone::VERSION} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} #{RUBY_PLATFORM}", connection.user_agent)
    
    connection = Sunstone::Connection.new(endpoint: 'http://localhost', user_agent: "MyGem/3.14")
    assert_equal("MyGem/3.14 Sunstone/#{Sunstone::VERSION} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} #{RUBY_PLATFORM}", connection.user_agent)
  end
  
end


