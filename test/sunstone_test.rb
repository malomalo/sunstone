require 'test_helper'

class SunstoneTest < Minitest::Test

  def setup
    stub_request(:get, "malomalo.io/ping").to_return(:body => "pong")
  end
  
  test "connection configuration" do
    ActiveRecord::Base.establish_connection(
      :adapter => 'sunstone',
      :site    => 'http://malomalo.io'
    )
    
    assert_equal ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter, ActiveRecord::Base.connection.class
    

    assert_equal 'malomalo.io', ActiveRecord::Base.connection.instance_variable_get(:@connection).host
    assert_equal 80, ActiveRecord::Base.connection.instance_variable_get(:@connection).port
    assert_equal false, ActiveRecord::Base.connection.instance_variable_get(:@connection).use_ssl
  end
  
  test "connection with user_agent" do
    ActiveRecord::Base.establish_connection(
      :adapter => 'sunstone',
      :site    => 'http://malomalo.io',
      :user_agent => 'MyAgent'
    )
    
    assert ActiveRecord::Base.connection.instance_variable_get(:@connection).user_agent.start_with?('MyAgent')
  end
  
  test 'connection with api key' do
    ActiveRecord::Base.establish_connection(
      :adapter => 'sunstone',
      :site    => 'http://myapikey@malomalo.io'
    )
    
    assert_equal 'myapikey', ActiveRecord::Base.connection.instance_variable_get(:@connection).api_key
  end
  

  # # Sunstone.with_cookie_store ================================================
  #
  # test '#with_cookie_store(store, &block) sets the cookie-store' do
  #   assert_nil Thread.current[:sunstone_cookie_store]
  #   Sunstone.with_cookie_store('my_store') do
  #     assert_equal 'my_store', Thread.current[:sunstone_cookie_store]
  #   end
  #   assert_nil Thread.current[:sunstone_cookie_store]
  # end
  #
  # # Sunstone.with_api_key ================================================
  #
  # test '#with_api_key(key, &block) sets the Api-Key' do
  #   assert_nil Thread.current[:sunstone_api_key]
  #   Sunstone.with_api_key('my_api_key') do
  #     assert_equal 'my_api_key', Thread.current[:sunstone_api_key]
  #   end
  #   assert_nil Thread.current[:sunstone_api_key]
  # end
  #
  # # Sunstone.send_request =====================================================
  #
  # test '#send_request(#<Net::HTTPRequest>)' do
  #   stub_request(:get, "http://testhost.com/test").to_return(:body => "get")
  #
  #   assert_equal('get', Sunstone.send_request(Net::HTTP::Get.new('/test')).body)
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>, body) with string body' do
  #   stub_request(:post, "http://testhost.com/test").with(:body => '{"key":"value"}').to_return(:body => "post")
  #
  #   assert_equal('post', Sunstone.send_request(Net::HTTP::Post.new('/test'), '{"key":"value"}').body)
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>, body) with IO body' do
  #   stub_request(:post, "http://testhost.com/test").with { |request|
  #     request.headers['Transfer-Encoding'] == "chunked" && request.body == '{"key":"value"}'
  #   }.to_return(:body => "post")
  #
  #   rd, wr = IO.pipe
  #   wr.write('{"key":"value"}')
  #   wr.close
  #
  #   assert_equal('post', Sunstone.send_request(Net::HTTP::Post.new('/test'), rd).body)
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>, body) with Ruby Object body' do
  #   stub_request(:post, "http://testhost.com/test").with(:body => '{"key":"value"}').to_return(:body => "post")
  #
  #   assert_equal('post', Sunstone.send_request(Net::HTTP::Post.new('/test'), {:key => 'value'}).body)
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>) raises Sunstone::Exceptions on non-200 responses' do
  #   stub_request(:get, "http://testhost.com/400").to_return(:status => 400)
  #   stub_request(:get, "http://testhost.com/401").to_return(:status => 401)
  #   stub_request(:get, "http://testhost.com/404").to_return(:status => 404)
  #   stub_request(:get, "http://testhost.com/410").to_return(:status => 410)
  #   stub_request(:get, "http://testhost.com/422").to_return(:status => 422)
  #   stub_request(:get, "http://testhost.com/450").to_return(:status => 450)
  #   stub_request(:get, "http://testhost.com/503").to_return(:status => 503)
  #   stub_request(:get, "http://testhost.com/550").to_return(:status => 550)
  #
  #   assert_raises(Sunstone::Exception::BadRequest)   { Sunstone.send_request(Net::HTTP::Get.new('/400')) }
  #   assert_raises(Sunstone::Exception::Unauthorized) { Sunstone.send_request(Net::HTTP::Get.new('/401')) }
  #   assert_raises(Sunstone::Exception::NotFound)     { Sunstone.send_request(Net::HTTP::Get.new('/404')) }
  #   assert_raises(Sunstone::Exception::Gone)         { Sunstone.send_request(Net::HTTP::Get.new('/410')) }
  #   assert_raises(Sunstone::Exception::ApiVersionUnsupported) { Sunstone.send_request(Net::HTTP::Get.new('/422')) }
  #   assert_raises(Sunstone::Exception)               { Sunstone.send_request(Net::HTTP::Get.new('/450')) }
  #   assert_raises(Sunstone::Exception::ServiceUnavailable)    { Sunstone.send_request(Net::HTTP::Get.new('/503')) }
  #   assert_raises(Sunstone::Exception)               { Sunstone.send_request(Net::HTTP::Get.new('/550')) }
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>, &block) returns value returned from &block' do
  #   stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')
  #
  #   value = Sunstone.send_request(Net::HTTP::Get.new('/test')) do |response|
  #     3215
  #   end
  #
  #   assert_equal 3215, value
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>, &block)' do
  #   stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')
  #
  #   Sunstone.send_request(Net::HTTP::Get.new('/test')) do |response|
  #     assert_equal 'get', response.body
  #   end
  #
  #   # make sure block is not called when not in valid_response_codes
  #   stub_request(:get, "http://testhost.com/test").to_return(:status => 401, :body => 'get')
  #
  #   assert_raises(Sunstone::Exception::Unauthorized) {
  #     Sunstone.send_request(Net::HTTP::Get.new('/test')) do |response|
  #       raise Sunstone::Exception, 'Should not get here'
  #     end
  #   }
  # end
  #
  # test '#send_request(#<Net::HTTPRequest>, &block) with block reading chunks' do
  #   rd, wr = IO.pipe
  #   rd = Net::BufferedIO.new(rd)
  #   wr.write(<<-DATA.gsub(/^ +/, '').gsub(/\n/, "\r\n"))
  #     HTTP/1.1 200 OK
  #     Content-Length: 5
  #
  #     hello
  #   DATA
  #
  #   res = Net::HTTPResponse.read_new(rd)
  #   connection = mock('connection')
  #   connection.stubs(:request).yields(res)
  #   Sunstone.stubs(:with_connection).yields(connection)
  #
  #   res.reading_body(rd, true) do
  #     Sunstone.send_request(Net::HTTP::Get.new('/test')) do |response|
  #       response.read_body do |chunk|
  #         assert_equal('hello', chunk)
  #       end
  #     end
  #   end
  # end
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
  # # Sunstone.get ==============================================================
  #
  # test '#get(path)' do
  #   stub_request(:get, "http://testhost.com/test").to_return(:body => "get")
  #
  #   assert_equal('get', Sunstone.get('/test').body)
  # end
  #
  # test '#get(path, params) with params as string' do
  #   stub_request(:get, "http://testhost.com/test").with(:query => {'key' => 'value'}).to_return(:body => "get")
  #
  #   assert_equal 'get', Sunstone.get('/test', 'key=value').body
  # end
  #
  # test '#get(path, params) with params as hash' do
  #   stub_request(:get, "http://testhost.com/test").with(:query => {'key' => 'value'}).to_return(:body => "get")
  #
  #   assert_equal 'get', Sunstone.get('/test', {:key => 'value'}).body
  # end
  #
  # test '#get(path, &block)' do
  #   stub_request(:get, "http://testhost.com/test").to_return(:body => 'get')
  #
  #   Sunstone.get('/test') do |response|
  #     assert_equal 'get', response.body
  #   end
  # end
  #
  # # Sunstone.post =============================================================
  #
  # test '#post(path)' do
  #   stub_request(:post, "http://testhost.com/test").to_return(:body => "post")
  #
  #   assert_equal('post', Sunstone.post('/test').body)
  # end
  #
  # test '#post(path, body)' do
  #   stub_request(:post, "http://testhost.com/test").with(:body => 'body').to_return(:body => "post")
  #
  #   assert_equal('post', Sunstone.post('/test', 'body').body)
  # end
  #
  # test '#post(path, &block)' do
  #   stub_request(:post, "http://testhost.com/test").to_return(:body => 'post')
  #
  #   Sunstone.post('/test') do |response|
  #     assert_equal 'post', response.body
  #   end
  # end
  #
  # # Sunstone.put ==============================================================
  #
  # test '#put(path)' do
  #   stub_request(:put, "http://testhost.com/test").to_return(:body => "put")
  #
  #   assert_equal('put', Sunstone.put('/test').body)
  # end
  #
  # test '#put(path, body)' do
  #   stub_request(:put, "http://testhost.com/test").with(:body => 'body').to_return(:body => "put")
  #
  #   assert_equal('put', Sunstone.put('/test', 'body').body)
  # end
  #
  # test '#put(path, &block)' do
  #   stub_request(:put, "http://testhost.com/test").to_return(:body => 'put')
  #
  #   Sunstone.put('/test') do |response|
  #     assert_equal 'put', response.body
  #   end
  # end
  #
  # # Sunstone.delete ===========================================================
  #
  # test '#delete' do
  #   stub_request(:delete, "http://testhost.com/test").to_return(:body => "delete")
  #
  #   assert_equal('delete', Sunstone.delete('/test').body)
  # end
  #
  # test '#delete(path, &block)' do
  #   stub_request(:delete, "http://testhost.com/test").to_return(:body => 'delete')
  #
  #   Sunstone.delete('/test') do |response|
  #     assert_equal 'delete', response.body
  #   end
  # end
  #
  # # Sunstone.ping =============================================================
  #
  # test '#ping' do
  #   stub_request(:get, "http://testhost.com/ping").to_return(:body => 'pong')
  #
  #   assert_equal( 'pong', Sunstone.ping )
  # end
  #
  # # Sunstone.config ===========================================================
  #
  # test '#config' do
  #   stub_request(:get, "http://testhost.com/config").to_return(:body => '{"server": "configs"}')
  #
  #   assert_equal( {:server => "configs"}, Sunstone.config )
  # end

end
