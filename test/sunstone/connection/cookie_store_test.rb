require 'test_helper'

class Sunstone::Connection::CookieStoreTest < ActiveSupport::TestCase

  test '#send_request(#<Net::HTTPRequest) adds cookies to the cookie store if present' do
    store = CookieStore::HashStore.new
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(:body => 'get', :headers => {'Set-Cookie' => 'foo=bar; Max-Age=3600'})

    Sunstone::Connection.with_cookie_store(store) { connection.get('/test') }
    
    assert_equal 1, store.instance_variable_get(:@domains).size
    assert_equal 1, store.instance_variable_get(:@domains)['testhost.com'].size
    assert_equal 1, store.instance_variable_get(:@domains)['testhost.com']['/test'].size
    assert_equal 'bar', store.instance_variable_get(:@domains)['testhost.com']['/test']['foo'].value
  end
  
  test '#send_request(#<Net::HTTPRequest) sends cookie header if cookie store is present' do
    store = CookieStore::HashStore.new
    connection = Sunstone::Connection.new(endpoint: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(
      headers: {
        'Set-Cookie' => 'foo=bar; Path="/" Max-Age=3600'
      },
      body: 'get'
    )
    cookie_stub = stub_request(:get, "http://testhost.com/verify").with { |req|
      req.headers['Cookie'] == 'foo=bar'
    }.to_return(body: 'verify')
    
    Sunstone::Connection.with_cookie_store(store) { connection.get('/test') }
    Sunstone::Connection.with_cookie_store(store) { connection.get('/verify') }
    
    assert_requested(cookie_stub)
  end
  
end