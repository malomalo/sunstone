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
require 'ext/active_record/calculations'
require 'ext/active_record/associations/builder/has_and_belongs_to_many'

require 'ext/arel/select_manager'
require 'ext/arel/nodes/eager_load'
require 'ext/arel/nodes/select_statement'
require 'ext/active_record/finder_methods'
require 'ext/active_record/batches'

# require 'sunstone/parser'

module Sunstone
  VERSION = 0.1

# TODO:
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
