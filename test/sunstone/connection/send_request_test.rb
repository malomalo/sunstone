require 'test_helper'

class Sunstone::Connection::SendRequestTest < ActiveSupport::TestCase

  test '#send_request(#<Net::HTTPRequest>) includes the api-key header when present' do
    connection = Sunstone::Connection.new(url: "http://my_api_key@example.com")
    
    test_stub = stub_request(:get, "http://example.com/verify").with { |req|
      req.headers['Api-Key'] == 'my_api_key'
    }
    connection.get('/verify')
    assert_requested(test_stub)
  end
  
  test '#send_request(#<Net::HTTPRequest>) includes the user_agent' do
    connection = Sunstone::Connection.new(url: "http://example.com")
    
    test_stub = stub_request(:get, "http://example.com/verify").with { |req|
      req.headers['User-Agent'] =~ /Sunstone\/\S+ Ruby\/\S+ \S+/
    }
    connection.get('/verify')
    assert_requested(test_stub)
    
    # Custom Agent
    connection = Sunstone::Connection.new(url: "http://example.com", user_agent: "MyClient/2")
    
    test_stub = stub_request(:get, "http://example.com/verify").with { |req|
      req.headers['User-Agent'] =~ /MyClient\/2 Sunstone\/\S+ Ruby\/\S+ \S+/
    }
    connection.get('/verify')
    assert_requested(test_stub)
  end
  
  test '#send_request(#<Net::HTTPRequest>)' do
    stub_request(:get, "http://testhost.com/test").to_return(body: 'get')

    connection = Sunstone::Connection.new(url: "http://testhost.com")
    assert_equal('get', connection.send_request(Net::HTTP::Get.new('/test')).body)
  end

  test '#send_request(#<Net::HTTPRequest>, body) with string body' do
    stub_request(:post, "http://testhost.com/test").with(
      body: '{"key":"value"}'
    ).to_return(
      body: "post"
    )

    connection = Sunstone::Connection.new(url: "http://testhost.com")
    assert_equal('post', connection.send_request(Net::HTTP::Post.new('/test'), '{"key":"value"}').body)
  end

  test '#send_request(#<Net::HTTPRequest>, body) with IO body' do
    stub_request(:post, "http://testhost.com/test").with { |request|
      request.headers['Transfer-Encoding'] == "chunked" && request.body == '{"key":"value"}'
    }.to_return(:body => "post")

    rd, wr = IO.pipe
    wr.write('{"key":"value"}')
    wr.close

    connection = Sunstone::Connection.new(url: "http://testhost.com")
    assert_equal('post', connection.send_request(Net::HTTP::Post.new('/test'), rd).body)
  end

  test '#send_request(#<Net::HTTPRequest>, body) with Ruby Object body' do
    stub_request(:post, "http://testhost.com/test").with(body: '{"key":"value"}').to_return(body: "post")

    connection = Sunstone::Connection.new(url: "http://testhost.com")
    assert_equal('post', connection.send_request(Net::HTTP::Post.new('/test'), {:key => 'value'}).body)
  end

  test '#send_request(#<Net::HTTPRequest>) raises Sunstone::Exceptions on non-200 responses' do
    stub_request(:get, "http://testhost.com/400").to_return(status: 400)
    stub_request(:get, "http://testhost.com/401").to_return(status: 401)
    stub_request(:get, "http://testhost.com/403").to_return(status: 403)
    stub_request(:get, "http://testhost.com/404").to_return(status: 404)
    stub_request(:get, "http://testhost.com/410").to_return(status: 410)
    stub_request(:get, "http://testhost.com/422").to_return(status: 422)
    stub_request(:get, "http://testhost.com/450").to_return(status: 450)
    stub_request(:get, "http://testhost.com/503").to_return(status: 503)
    stub_request(:get, "http://testhost.com/550").to_return(status: 550)

    connection = Sunstone::Connection.new(url: "http://testhost.com")
    assert_raises(Sunstone::Exception::BadRequest)   { connection.send_request(Net::HTTP::Get.new('/400')) }
    assert_raises(Sunstone::Exception::Unauthorized) { connection.send_request(Net::HTTP::Get.new('/401')) }
    assert_raises(Sunstone::Exception::Forbidden) { connection.send_request(Net::HTTP::Get.new('/403')) }
    assert_raises(Sunstone::Exception::NotFound)     { connection.send_request(Net::HTTP::Get.new('/404')) }
    assert_raises(Sunstone::Exception::Gone)         { connection.send_request(Net::HTTP::Get.new('/410')) }
    assert_raises(Sunstone::Exception::ApiVersionUnsupported) { connection.send_request(Net::HTTP::Get.new('/422')) }
    assert_raises(Sunstone::Exception)               { connection.send_request(Net::HTTP::Get.new('/450')) }
    assert_raises(Sunstone::Exception::ServiceUnavailable)    { connection.send_request(Net::HTTP::Get.new('/503')) }
    assert_raises(Sunstone::ServerError)               { connection.send_request(Net::HTTP::Get.new('/550')) }
  end

  test '#send_request(#<Net::HTTPRequest>, &block) returns value returned from &block' do
    stub_request(:get, "http://testhost.com/test").to_return(body: 'get')

    connection = Sunstone::Connection.new(url: "http://testhost.com")
    value = connection.send_request(Net::HTTP::Get.new('/test')) do |response|
      3215
    end

    assert_equal 3215, value
  end

  test '#send_request(#<Net::HTTPRequest>, &block)' do
    connection = Sunstone::Connection.new(url: "http://testhost.com")
    stub_request(:get, "http://testhost.com/test").to_return(body: 'get')

    connection.send_request(Net::HTTP::Get.new('/test')) do |response|
      assert_equal 'get', response.body
    end

    # make sure block is not called when not in valid_response_codes
    stub_request(:get, "http://testhost.com/test").to_return(status: 401, body: 'get')

    assert_raises(Sunstone::Exception::Unauthorized) {
      connection.send_request(Net::HTTP::Get.new('/test')) do |response|
        raise Sunstone::Exception, 'Should not get here'
      end
    }
  end

  test '#send_request(#<Net::HTTPRequest>, &block) with block reading chunks' do
    connection = Sunstone::Connection.new(url: "http://testhost.com")
    
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
  
  # TODO: support multple depreaction-notice headers
  test 'deprecation warning printed when deprecation header returned' do
    connection = Sunstone::Connection.new(url: "http://testhost.com")
    
    stub_request(:get, "http://testhost.com/test").to_return(
      body: 'get',
      headers: { 'Deprecation-Notice': 'my deprecation message' }
    )
    
    ActiveSupport::Deprecation.expects(:warn).with('my deprecation message')
    
    connection.send_request(Net::HTTP::Get.new('/test'))
  end
  
end