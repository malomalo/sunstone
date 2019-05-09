# _Sunstone_ is a low-level API. It provides basic HTTP #get, #post, #put, and
# #delete calls to the Sunstone Server. It can also provides basic error
# checking of responses.
module Sunstone
  class Connection

    attr_reader :api_key, :host, :port, :use_ssl

    # Initialize a connection a Sunstone API server.
    #
    # Options:
    #
    # * <tt>:url</tt> - An optional url used to set the protocol, host, port,
    #   and api_key
    # * <tt>:host</tt> - The default is to connect to 127.0.0.1.
    # * <tt>:port</tt> - Defaults to 80.
    # * <tt>:use_ssl</tt> - Defaults to false.
    # * <tt>:api_key</tt> - An optional token to send in the `Api-Key` header
    # * <tt>:user_agent</tt> - An optional string. Will be joined with other
    #                          User-Agent info.
    def initialize(config)
      if config[:url]
        uri = URI.parse(config.delete(:url))
        config[:api_key] ||= (uri.user ? CGI.unescape(uri.user) : nil)
        config[:host]    ||= uri.host
        config[:port]    ||= uri.port
        config[:use_ssl] ||= (uri.scheme == 'https')
      end

      [:api_key, :host, :port, :use_ssl, :user_agent].each do |key|
        self.instance_variable_set(:"@#{key}", config[key])
      end

      @connection = Net::HTTP.new(host, port)
      @connection.max_retries         = 0
      @connection.open_timeout        = 5
      @connection.read_timeout        = 30
      @connection.write_timeout       = 5
      @connection.ssl_timeout         = 5
      @connection.keep_alive_timeout  = 30
      @connection.use_ssl = use_ssl
      if use_ssl && config[:ca_cert]
        @connection.cert_store = OpenSSL::X509::Store.new
        @connection.cert_store.add_cert(OpenSSL::X509::Certificate.new(File.read(config[:ca_cert])))
      end

      true
    end

    # Ping the Sunstone. If everything is configured and operating correctly
    # <tt>"pong"</tt> will be returned. Otherwise and Sunstone::Exception should
    # be thrown.
    #
    #  #!ruby
    #  Sunstone.ping # => "pong"
    #
    #  Sunstone.ping # raises Sunstone::Exception::ServiceUnavailable if a
    #  503 is returned
    def ping
      get('/ping').body
    end
    
    def connect!
      @connection.start
    end
    
    def active?
      @connection.active?
    end
    
    def reconnect!
      disconnect!
      connect!
    end
    
    def disconnect!
      @connection.finish if @connection.active?
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
    
    def url(path=nil)
      "http#{use_ssl ? 's' : ''}://#{host}#{port != 80 ? (port == 443 && use_ssl ? '' : ":#{port}") : ''}#{path}"
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
      if request.method != 'GET' && Thread.current[:sunstone_transaction_count]
        if Thread.current[:sunstone_transaction_count] == 1 && !Thread.current[:sunstone_request_sent]
          Thread.current[:sunstone_request_sent] = request
        elsif Thread.current[:sunstone_request_sent]
          log_mess = request.path.split('?', 2)
          log_mess += Thread.current[:sunstone_request_sent].path.split('?', 2)
          raise ActiveRecord::StatementInvalid, <<~MSG
            Cannot send multiple request in a transaction.
            
            Trying to send:
              #{request.method} #{log_mess[0]} #{(log_mess[1] && !log_mess[1].empty?) ? MessagePack.unpack(CGI.unescape(log_mess[1])) : '' }
            
            Already sent:
              #{Thread.current[:sunstone_request_sent].method} #{log_mess[2]} #{(log_mess[3] && !log_mess[3].empty?) ? MessagePack.unpack(CGI.unescape(log_mess[3])) : '' }
          MSG
        else
          log_mess = request.path.split('?', 2)
          raise ActiveRecord::StatementInvalid, <<~MSG
            Cannot send multiple request in a transaction.
            
            Trying to send:
              #{request.method} #{log_mess[0]} #{(log_mess[1] && !log_mess[1].empty?) ? MessagePack.unpack(CGI.unescape(log_mess[1])) : '' }
          MSG
        end
      end
      
      request_uri = url(request.path)
      request_headers.each { |k, v| request[k] = v }
      request['Content-Type'] ||= 'application/json'
      
      if Thread.current[:sunstone_cookie_store]
        request['Cookie'] = Thread.current[:sunstone_cookie_store].cookie_header_for(request_uri)
      end

      if body.is_a?(IO)
        request['Transfer-Encoding'] = 'chunked'
        request.body_stream =  body
      elsif body.is_a?(String)
        request.body = body
      elsif body
        request.body = JSON.generate(body)
      end

      return_value = nil
      begin
        close_connection = false
        @connection.request(request) do |response|
          if response['Deprecation-Notice']
            ActiveSupport::Deprecation.warn(response['Deprecation-Notice'])
          end

          validate_response_code(response)

          # Get the cookies
          response.each_header do |key, value|
            case key.downcase
            when 'set-cookie'
              if Thread.current[:sunstone_cookie_store]
                Thread.current[:sunstone_cookie_store].set_cookie(request_uri, value)
              end
            when 'connection'
              close_connection = (value == 'close')
            end
          end

          if block_given?
            return_value = yield(response)
          else
            return_value = response
          end
        end
        @connection.finish if close_connection
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
      @server_config ||= JSON.parse(get('/config').body, symbolize_names: true)
    end

    private

    def request_headers
      headers = Thread.current[:sunstone_headers]&.clone || {}
      headers['Accept'] = 'application/json'
      headers['User-Agent'] = user_agent
      headers['Api-Version'] = '0.1.0'
      headers['Connection'] = 'keep-alive'
      
      request_api_key = Thread.current[:sunstone_api_key] || api_key
      headers['Api-Key'] = request_api_key if request_api_key
      
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
          raise Sunstone::Exception::BadRequest, response.body
        when 401
          raise Sunstone::Exception::Unauthorized, response.body
        when 403
          raise Sunstone::Exception::Forbidden, response.body
        when 404
          raise Sunstone::Exception::NotFound, response.body
        when 410
          raise Sunstone::Exception::Gone, response.body
        when 422
          raise Sunstone::Exception::ApiVersionUnsupported, response.body
        when 503
          raise Sunstone::Exception::ServiceUnavailable, response.body
        when 301
          raise Sunstone::Exception::MovedPermanently, response.body
        when 502
          raise Sunstone::Exception::BadGateway, response.body
        when 500..599
          raise Sunstone::ServerError, response.body
        else
          raise Sunstone::Exception, response.body
        end
      end
    end
    
    def self.use_cookie_store(store)
      Thread.current[:sunstone_cookie_store] = store
    end
  
    def self.with_cookie_store(store)
      Thread.current[:sunstone_cookie_store] = store
      yield
    ensure
      Thread.current[:sunstone_cookie_store] = nil
    end

  end
end
