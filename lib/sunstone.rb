require 'wankel'
require 'cookie_store'

require 'active_support'
require 'active_support/core_ext'

require 'active_model'

require 'active_record'

require 'sunstone/connection'
require 'sunstone/exception'
require 'ext/active_record/statement_cache'
require 'ext/active_record/relation'

# require 'sunstone/parser'

module Sunstone
  VERSION = 0.1

# TODO:
#   # Set a cookie jar to use during request sent during the
#   def with_cookie_store(store, &block)
#     Thread.current[:sunstone_cookie_store] = store
#     yield
#   ensure
#     Thread.current[:sunstone_cookie_store] = nil
#   end
#
#
#   # Get a connection from the connection pool and perform the block with
#   # the connection
#   def with_connection(&block)
#     connection_pool.with({}, &block)
#   end
#
#   private
#
#   def request_headers
#     headers = {
#       'Content-Type'            => 'application/json',
#       'User-Agent'              => user_agent
#     }
#
#     headers['Api-Key'] = api_key if api_key
#
#     headers
#   end
#
end