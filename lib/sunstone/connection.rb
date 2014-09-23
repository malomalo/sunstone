require 'uri'
require 'net/http'
require 'net/https'

# _Sunstone_ is a low-level API. It provides basic HTTP #get, #post, #put, and
# #delete calls to the Sunstone Server. It can also provides basic error
# checking of responses.
module Sunstone
  class Connection
    
    # Set the User-Agent of the client. Will be joined with other User-Agent info
    attr_writer :user_agent
    attr_accessor :api_key, :host, :port, :use_ssl
    
    # Initialize a connection a Sunstone API server.
    #
    # Options:
    #
    # * <tt>:site</tt> - An optional url used to set the protocol, host, port,
    #   and api_key
    # * <tt>:host</tt> - The default is to connect to 127.0.0.1.
    # * <tt>:port</tt> - Defaults to 80.
    # * <tt>:use_ssl</tt> - Defaults to false.
    # * <tt>:api_key</tt> - An optional token to send in the `Api-Key` header
    def initialize(config)
      if config[:site]
        uri = URI.parse(config.delete(:site))
        config[:api_key] ||= (uri.user ? CGI.unescape(uri.user) : nil)
        config[:host]    ||= uri.host
        config[:port]    ||= uri.port
        config[:use_ssl] ||= (uri.scheme == 'https')
      end
      
      [:api_key, :host, :port, :use_ssl, :user_agent].each do |key|
        self.send(:"#{key}=", config[key])
      end
      
      # @connection = Net::HTTP.new(host, port)
      # @connection.use_ssl = use_ssl
    end
    
    # Ping the Sunstone. If everything is configured and operating correctly
    # <tt>"pong"</tt> will be returned. Otherwise and Sunstone::Exception should be
    # thrown.
    #
    #  #!ruby
    #  Sunstone.ping # => "pong"
    #
    #  Sunstone.ping # raises Sunstone::Exception::ServiceUnavailable if a 503 is returned
    def ping
      get('/ping').body
    end

    # Returns the User-Agent of the client. Defaults to:
    # "sunstone-ruby/SUNSTONE_VERSION RUBY_VERSION-pPATCH_LEVEL PLATFORM"
    def user_agent
      [
        @user_agent,
        "Sunstone/#{Sunstone::VERSION}",
        "Ruby/#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}",
        RUBY_PLATFORM
      ].compact.join(' ')
    end
   
    # Sends a Net::HTTPRequest to the server. The headers returned from
    # Sunestone#headers are automatically added to the request. The appropriate
    # error is raised if the response is not in the 200..299 range.
    #
    # Paramaters::
    #
    # * +request+ - A Net::HTTPRequest to send to the server
    # * +body+ - Optional, a String, IO Object, or a Ruby object which is 
    #            converted into JSON and sent as the body
    # * +block+ - An optional block to call with the +Net::HTTPResponse+ object.
    #
    # Return Value::
    #
    #  Returns the return value of the <tt>&block</tt> if given, otherwise the
    #  response object (a Net::HTTPResponse)
    #
    # Examples:
    #
    #  #!ruby
    #  Sunstone.send_request(#<Net::HTTP::Get>) # => #<Net::HTTP::Response>
    #
    #  Sunstone.send_request(#<Net::HTTP::Get @path="/404">) # => raises Sunstone::Exception::NotFound
    #
    #  # this will still raise an exception if the response_code is not valid
    #  # and the block will not be called
    #  Sunstone.send_request(#<Net::HTTP::Get>) do |response|
    #    # ...
    #  end
    #
    #  # The following example shows how to stream a response:
    #  Sunstone.send_request(#<Net::HTTP::Get>) do |response|
    #    response.read_body do |chunk|
    #      io.write(chunk)
    #    end
    #  end
    def send_request(request, body=nil, &block)
      request_uri = "http#{use_ssl ? 's' : ''}://#{host}#{port != 80 ? (port == 443 && use_ssl ? '' : ":#{port}") : ''}#{request.path}"
      request_headers.each { |k, v| request[k] = v }
      
      if Thread.current[:sunstone_cookie_store]
        request['Cookie'] = Thread.current[:sunstone_cookie_store].cookie_header_for(request_uri)
      end
      
      if body.is_a?(IO)
        request['Transfer-Encoding'] = 'chunked'
        request.body_stream =  body
      elsif body.is_a?(String)
        request.body = body
      elsif body
        request.body = Wankel.encode(body)
      end

      return_value = nil
      # @connection.request(request) do |response|
      Net::HTTP.new(host, port).request(request) do |response|

        if response['API-Version-Deprecated']
          logger.warn("DEPRECATION WARNING: API v#{API_VERSION} is being phased out")
        end

        validate_response_code(response)

        # Get the cookies
        response.each_header do |key, value|
          if key.downcase == 'set-cookie' && Thread.current[:sunstone_cookie_store]
            Thread.current[:sunstone_cookie_store].set_cookie(request_uri, value)
          end
        end

        if block_given?
          return_value =yield(response)
        else
          return_value =response
        end
      end

      return_value
    end

    # Send a GET request to +path+ on the Sunstone Server via +Sunstone#send_request+.
    # See +Sunstone#send_request+ for more details on how the response is handled.
    #
    # Paramaters::
    #
    # * +path+ - The +path+ on the server to GET to.
    # * +params+ - Either a String, Hash, or Ruby Object that responds to
    #              #to_param. Appended on the URL as query params
    # * +block+ - An optional block to call with the +Net::HTTPResponse+ object.
    #
    # Return Value::
    #
    #  See +Sunstone#send_request+
    #
    # Examples:
    #
    #  #!ruby
    #  Sunstone.get('/example') # => #<Net::HTTP::Response>
    #
    #  Sunstone.get('/example', 'query=stuff') # => #<Net::HTTP::Response>
    #
    #  Sunstone.get('/example', {:query => 'stuff'}) # => #<Net::HTTP::Response>
    #
    #  Sunstone.get('/404') # => raises Sunstone::Exception::NotFound
    #
    #  Sunstone.get('/act') do |response|
    #    # ...
    #  end
    def get(path, params='', &block)
      params ||= ''
      request = Net::HTTP::Get.new(path + '?' + params.to_param)
    
      send_request(request, nil, &block)
    end
    
    # Send a POST request to +path+ on the Sunstone Server via +Sunstone#send_request+.
    # See +Sunstone#send_request+ for more details on how the response is handled.
    #
    # Paramaters::
    #
    # * +path+ - The +path+ on the server to POST to.
    # * +body+ - Optional, See +Sunstone#send_request+.
    # * +block+ - Optional, See +Sunstone#send_request+
    #
    # Return Value::
    #
    #  See +Sunstone#send_request+
    #
    # Examples:
    #
    #  #!ruby
    #  Sunstone.post('/example') # => #<Net::HTTP::Response>
    #
    #  Sunstone.post('/example', 'body') # => #<Net::HTTP::Response>
    #
    #  Sunstone.post('/example', #<IO Object>) # => #<Net::HTTP::Response>
    #
    #  Sunstone.post('/example', {:example => 'data'}) # => #<Net::HTTP::Response>
    #
    #  Sunstone.post('/404') # => raises Sunstone::Exception::NotFound
    #
    #  Sunstone.post('/act') do |response|
    #    # ...
    #  end
    def post(path, body=nil, &block)
      request = Net::HTTP::Post.new(path)
    
      send_request(request, body, &block)
    end
    
    # Send a PUT request to +path+ on the Sunstone Server via +Sunstone#send_request+.
    # See +Sunstone#send_request+ for more details on how the response is handled.
    #
    # Paramaters::
    #
    # * +path+ - The +path+ on the server to POST to.
    # * +body+ - Optional, See +Sunstone#send_request+.
    # * +block+ - Optional, See +Sunstone#send_request+
    #
    # Return Value::
    #
    #  See +Sunstone#send_request+
    #
    # Examples:
    #
    #  #!ruby
    #  Sunstone.put('/example') # => #<Net::HTTP::Response>
    #
    #  Sunstone.put('/example', 'body') # => #<Net::HTTP::Response>
    #
    #  Sunstone.put('/example', #<IO Object>) # => #<Net::HTTP::Response>
    #
    #  Sunstone.put('/example', {:example => 'data'}) # => #<Net::HTTP::Response>
    #
    #  Sunstone.put('/404') # => raises Sunstone::Exception::NotFound
    #
    #  Sunstone.put('/act') do |response|
    #    # ...
    #  end
    def put(path, body=nil, *valid_response_codes, &block)
      request = Net::HTTP::Put.new(path)
    
      send_request(request, body, &block)
    end
  
    # Send a DELETE request to +path+ on the Sunstone Server via +Sunstone#send_request+.
    # See +Sunstone#send_request+ for more details on how the response is handled
    #
    # Paramaters::
    #
    # * +path+ - The +path+ on the server to POST to.
    # * +block+ - Optional, See +Sunstone#send_request+
    #
    # Return Value::
    #
    #  See +Sunstone#send_request+
    #
    # Examples:
    #
    #  #!ruby
    #  Sunstone.delete('/example') # => #<Net::HTTP::Response>
    #
    #  Sunstone.delete('/404') # => raises Sunstone::Exception::NotFound
    #
    #  Sunstone.delete('/act') do |response|
    #    # ...
    #  end
    def delete(path, &block)
      request = Net::HTTP::Delete.new(path)
    
      send_request(request, nil, &block)
    end

    def server_config
      @server_config ||= Wankel.parse(get('/config').body, :symbolize_keys => true)
    end
    
    private
    
    def request_headers
      headers = {
        'Content-Type'            => 'application/json',
        'User-Agent'              => user_agent,
        'Api-Version' => '0.1.0'
      }
    
      headers['Api-Key'] = api_key if api_key
    
      headers
    end

    # Raise an Sunstone::Exception based on the response_code, unless the response_code
    # is include in the valid_response_codes Array
    #
    # Paramaters::
    #
    # * +response+ - The Net::HTTP::Response object
    #
    # Return Value::
    #
    #  If an exception is not raised the +response+ is returned
    #
    # Examples:
    #
    #  #!ruby
    #  Sunstone.validate_response_code(<Net::HTTP::Response @code=200>) # => <Net::HTTP::Response @code=200>
    #
    #  Sunstone.validate_response_code(<Net::HTTP::Response @code=404>) # => raises Sunstone::Exception::NotFound
    #
    #  Sunstone.validate_response_code(<Net::HTTP::Response @code=500>) # => raises Sunstone::Exception
    def validate_response_code(response)
      code = response.code.to_i
    
      if !(200..299).include?(code)
        case code
        when 400
          raise Sunstone::Exception::BadRequest, response
        when 401
          raise Sunstone::Exception::Unauthorized, response
        when 404
          raise Sunstone::Exception::NotFound, response
        when 410
          raise Sunstone::Exception::Gone, response
        when 422
          raise Sunstone::Exception::ApiVersionUnsupported, response
        when 503
          raise Sunstone::Exception::ServiceUnavailable, response
        when 301
          raise Sunstone::Exception::MovedPermanently, response
        when 300..599
          raise Sunstone::Exception, response
        else
          raise Sunstone::Exception, response
        end
      end
    end
    
  end
end
