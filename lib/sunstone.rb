require 'uri'
require 'net/http'
require 'net/https'

require 'json'
require 'msgpack'
require 'cookie_store' # optional

require "active_record"

# Adapter
require File.expand_path(File.join(__FILE__, '../sunstone/version'))
require File.expand_path(File.join(__FILE__, '../sunstone/exception'))
require File.expand_path(File.join(__FILE__, '../sunstone/connection'))
require File.expand_path(File.join(__FILE__, '../active_record/connection_adapters/sunstone_adapter'))
require File.expand_path(File.join(__FILE__, '../active_record/connection_adapters/sunstone/type_metadata'))

# Arel Adapters
require File.expand_path(File.join(__FILE__, '../arel/visitors/sunstone'))
require File.expand_path(File.join(__FILE__, '../arel/collectors/sunstone'))

# ActiveRecord Extensions
require File.expand_path(File.join(__FILE__, '../../ext/active_record/statement_cache'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/associations'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/relation'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/relation/calculations'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/relation/query_methods'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/persistence'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/callbacks'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/attribute_methods'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/transactions'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/associations/collection_association'))

require File.expand_path(File.join(__FILE__, '../../ext/active_support/core_ext/object/to_query'))

require File.expand_path(File.join(__FILE__, '../../ext/arel/select_manager'))
require File.expand_path(File.join(__FILE__, '../../ext/arel/nodes/eager_load'))
require File.expand_path(File.join(__FILE__, '../../ext/arel/attributes/empty_relation'))
require File.expand_path(File.join(__FILE__, '../../ext/arel/nodes/select_statement'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/finder_methods'))

if ActiveRecord::VERSION::MAJOR == 6 && ActiveRecord::VERSION::MINOR == 1
  # Patch to allow Rails 6.1 pass url to adapter, all other versions work
  require 'active_record/database_configurations'
  class ActiveRecord::DatabaseConfigurations::UrlConfig
    private
    def build_url_hash
      if url.nil? || %w(jdbc: http: https:).any? { |protocol| url.start_with?(protocol) }
        { url: url }
      else
        ConnectionUrlResolver.new(url).to_hash
      end
    end
  end
end
