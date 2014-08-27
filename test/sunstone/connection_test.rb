require 'test_helper'

class Sunstone::ConnectionTest < Minitest::Test

  # ::new =====================================================================
  test "setting the site sets the api_key" do
    connection = Sunstone::Connection.new(:site => 'https://my_api_key@localhost')
    assert_equal('my_api_key', connection.api_key)
  end

  test "setting the site sets the host" do
    connection = Sunstone::Connection.new(:site => 'https://my_api_key@example.com')
    assert_equal('example.com', connection.host)
  end

  test "setting the site sets the port" do
    connection = Sunstone::Connection.new(:site => 'http://my_api_key@localhost')
    assert_equal(80, connection.port)

    connection = Sunstone::Connection.new(:site => 'https://my_api_key@localhost')
    assert_equal(443, connection.port)
    
    connection = Sunstone::Connection.new(:site => 'https://my_api_key@localhost:4321')
    assert_equal(4321, connection.port)
  end

  test "setting the site sets the use_ssl option" do
    connection = Sunstone::Connection.new(:site => 'http://my_api_key@localhost')
    assert_equal(false, connection.use_ssl)
    
    connection = Sunstone::Connection.new(:site => 'https://my_api_key@localhost')
    assert_equal(true, connection.use_ssl)
  end
  
  test "setting the user_agent appends it to the User-Agent" do
    connection = Sunstone::Connection.new(:site => 'http://my_api_key@localhost')
    assert_equal("Sunstone/#{Sunstone::VERSION} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} #{RUBY_PLATFORM}", connection.user_agent)
    
    connection = Sunstone::Connection.new(:site => 'http://my_api_key@localhost', :user_agent => "MyGem/3.14")
    assert_equal("MyGem/3.14 Sunstone/#{Sunstone::VERSION} Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} #{RUBY_PLATFORM}", connection.user_agent)
  end

  #send_request =============================================================

  test '#send_request(#<Net::HTTPRequest>)' do
    stub_request(:get, "http://testhost.com/test").to_return(:body => "get")
    
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    assert_equal('get', connection.send_request(Net::HTTP::Get.new('/test')).body)
  end

  test '#send_request(#<Net::HTTPRequest>, body) with string body' do
    stub_request(:post, "http://testhost.com/test").with(:body => '{"key":"value"}').to_return(:body => "post")

    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    assert_equal('post', connection.send_request(Net::HTTP::Post.new('/test'), '{"key":"value"}').body)
  end

  test '#send_request(#<Net::HTTPRequest>, body) with IO body' do
    stub_request(:post, "http://testhost.com/test").with { |request|
      request.headers['Transfer-Encoding'] == "chunked" && request.body == '{"key":"value"}'
    }.to_return(:body => "post")

    rd, wr = IO.pipe
    wr.write('{"key":"value"}')
    wr.close

    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    assert_equal('post', connection.send_request(Net::HTTP::Post.new('/test'), rd).body)
  end

  test '#send_request(#<Net::HTTPRequest>, body) with Ruby Object body' do
    stub_request(:post, "http://testhost.com/test").with(:body => '{"key":"value"}').to_return(:body => "post")

    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    assert_equal('post', connection.send_request(Net::HTTP::Post.new('/test'), {:key => 'value'}).body)
  end

  test '#send_request(#<Net::HTTPRequest>) raises Sunstone::Exceptions on non-200 responses' do
    stub_request(:get, "http://testhost.com/400").to_return(:status => 400)
    stub_request(:get, "http://testhost.com/401").to_return(:status => 401)
    stub_request(:get, "http://testhost.com/404").to_return(:status => 404)
    stub_request(:get, "http://testhost.com/410").to_return(:status => 410)
    stub_request(:get, "http://testhost.com/422").to_return(:status => 422)
    stub_request(:get, "http://testhost.com/450").to_return(:status => 450)
    stub_request(:get, "http://testhost.com/503").to_return(:status => 503)
    stub_request(:get, "http://testhost.com/550").to_return(:status => 550)

    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    assert_raises(Sunstone::Exception::BadRequest)   { connection.send_request(Net::HTTP::Get.new('/400')) }
    assert_raises(Sunstone::Exception::Unauthorized) { connection.send_request(Net::HTTP::Get.new('/401')) }
    assert_raises(Sunstone::Exception::NotFound)     { connection.send_request(Net::HTTP::Get.new('/404')) }
    assert_raises(Sunstone::Exception::Gone)         { connection.send_request(Net::HTTP::Get.new('/410')) }
    assert_raises(Sunstone::Exception::ApiVersionUnsupported) { connection.send_request(Net::HTTP::Get.new('/422')) }
    assert_raises(Sunstone::Exception)               { connection.send_request(Net::HTTP::Get.new('/450')) }
    assert_raises(Sunstone::Exception::ServiceUnavailable)    { connection.send_request(Net::HTTP::Get.new('/503')) }
    assert_raises(Sunstone::Exception)               { connection.send_request(Net::HTTP::Get.new('/550')) }
  end

  test '#send_request(#<Net::HTTPRequest>, &block) returns value returned from &block' do
    stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')

    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    value = connection.send_request(Net::HTTP::Get.new('/test')) do |response|
      3215
    end

    assert_equal 3215, value
  end

  test '#send_request(#<Net::HTTPRequest>, &block)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')

    connection.send_request(Net::HTTP::Get.new('/test')) do |response|
      assert_equal 'get', response.body
    end

    # make sure block is not called when not in valid_response_codes
    stub_request(:get, "http://testhost.com/test").to_return(:status => 401, :body => 'get')

    assert_raises(Sunstone::Exception::Unauthorized) {
      connection.send_request(Net::HTTP::Get.new('/test')) do |response|
        raise Sunstone::Exception, 'Should not get here'
      end
    }
  end

  test '#send_request(#<Net::HTTPRequest>, &block) with block reading chunks' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    
    rd, wr = IO.pipe
    rd = Net::BufferedIO.new(rd)
    wr.write(<<-DATA.gsub(/^ +/, '').gsub(/\n/, "\r\n"))
      HTTP/1.1 200 OK
      Content-Length: 5

      hello
    DATA

    res = Net::HTTPResponse.read_new(rd)
    mock_connection = mock('connection')
    mock_connection.stubs(:request).yields(res)
    connection.instance_variable_set(:@connection, mock_connection)

    res.reading_body(rd, true) do
      connection.send_request(Net::HTTP::Get.new('/test')) do |response|
        response.read_body do |chunk|
          assert_equal('hello', chunk)
        end
      end
    end
  end
  #
  # test '#send_request(#<Net::HTTPRequest) adds cookies to the cookie store if present' do
  #   store = CookieStore::HashStore.new
  #   stub_request(:get, "http://testhost.com/test").to_return(:body => 'get', :headers => {'Set-Cookie' => 'foo=bar; Max-Age=3600'})
  #
  #   Sunstone.with_cookie_store(store) do
  #     Sunstone.send_request(Net::HTTP::Get.new('/test'))
  #   end
  #
  #   assert_equal 1, store.instance_variable_get(:@domains).size
  #   assert_equal 1, store.instance_variable_get(:@domains)['testhost.com'].size
  #   assert_equal 1, store.instance_variable_get(:@domains)['testhost.com']['/test'].size
  #   assert_equal 'bar', store.instance_variable_get(:@domains)['testhost.com']['/test']['foo'].value
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>) includes the headers' do
  #   stub_request(:get, "http://testhost.com/test").with(:headers => {
  #     'Api-Key'      => 'test_api_key',
  #     'Content-Type' => 'application/json',
  #     'User-Agent'   => Sunstone.user_agent
  #   }).to_return(:body => "get")
  #
  #   assert_equal('get', Sunstone.send_request(Net::HTTP::Get.new('/test')).body)
  #
  #   # Test without api key
  #   Sunstone.site = "http://testhost.com"
  #   stub_request(:get, "http://testhost.com/test").with(:headers => {
  #     'Content-Type'=>'application/json',
  #     'User-Agent'=>'Sunstone/0.1 Ruby/2.1.1-p76 x86_64-darwin13.0'
  #   }).to_return(:body => "get")
  #
  #   assert_equal('get', Sunstone.send_request(Net::HTTP::Get.new('/test')).body)
  # end
  
  #
  # # Sunstone.with_cookie_store ================================================
  #
  # test '#with_cookie_store(store, &block) sets the cookie-store' do
  #   assert_nil Thread.current[:sunstone_cookie_store]
  #   Sunstone.with_cookie_store('my_store') do
  #     assert_equal 'my_store', Thread.current[:sunstone_cookie_store]
  #   end
  #   assert_nil Thread.current[:sunstone_cookie_store]
  # end

  # Sunstone.get ==============================================================

  test '#get(path)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(:body => "get")

    assert_equal('get', connection.get('/test').body)
  end

  test '#get(path, params) with params as string' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/test").with(:query => {'key' => 'value'}).to_return(:body => "get")

    assert_equal 'get', connection.get('/test', 'key=value').body
  end

  test '#get(path, params) with params as hash' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/test").with(:query => {'key' => 'value'}).to_return(:body => "get")

    assert_equal 'get', connection.get('/test', {:key => 'value'}).body
  end

  test '#get(path, &block)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')

    connection.get('/test') do |response|
      assert_equal 'get', response.body
    end
  end

  # Sunstone.post =============================================================

  test '#post(path)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:post, "http://testhost.com/test").to_return(:body => "post")

    assert_equal('post', connection.post('/test').body)
  end

  test '#post(path, body)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:post, "http://testhost.com/test").with(:body => 'body').to_return(:body => "post")

    assert_equal('post', connection.post('/test', 'body').body)
  end

  test '#post(path, &block)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:post, "http://testhost.com/test").to_return(:body => 'post')

    connection.post('/test') do |response|
      assert_equal 'post', response.body
    end
  end

  # Sunstone.put ==============================================================

  test '#put(path)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:put, "http://testhost.com/test").to_return(:body => "put")

    assert_equal('put', connection.put('/test').body)
  end

  test '#put(path, body)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:put, "http://testhost.com/test").with(:body => 'body').to_return(:body => "put")

    assert_equal('put', connection.put('/test', 'body').body)
  end

  test '#put(path, &block)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:put, "http://testhost.com/test").to_return(:body => 'put')

    connection.put('/test') do |response|
      assert_equal 'put', response.body
    end
  end

  # Sunstone.delete ===========================================================

  test '#delete' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:delete, "http://testhost.com/test").to_return(:body => "delete")

    assert_equal('delete', connection.delete('/test').body)
  end

  test '#delete(path, &block)' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:delete, "http://testhost.com/test").to_return(:body => 'delete')

    connection.delete('/test') do |response|
      assert_equal 'delete', response.body
    end
  end

  # #ping =====================================================================

  test '#ping' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/ping").to_return(:body => 'pong')

    assert_equal( 'pong', connection.ping )
  end

  # #server_config ===========================================================

  test '#config' do
    connection = Sunstone::Connection.new(:site => "http://test_api_key@testhost.com")
    stub_request(:get, "http://testhost.com/config").to_return(:body => '{"server": "configs"}')

    assert_equal( {:server => "configs"}, connection.server_config )
  end



end