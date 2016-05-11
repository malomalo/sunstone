require 'test_helper'

class Sunstone::ConnectionTest < Minitest::Test

  # #ping =====================================================================

  test '#ping' do
    connection = Sunstone::Connection.new(url: "http://testhost.com")
    stub_request(:get, "http://testhost.com/ping").to_return(:body => 'pong')

    assert_equal( 'pong', connection.ping )
  end

  # #server_config ===========================================================

  test '#config' do
    connection = Sunstone::Connection.new(url: "http://testhost.com")
    stub_request(:get, "http://testhost.com/config").to_return(:body => '{"server": "configs"}')

    assert_equal( {:server => "configs"}, connection.server_config )
  end

end