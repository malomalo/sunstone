require 'wankel'
require 'cookie_store'
require 'active_record'

require File.expand_path(File.join(__FILE__, '../sunstone/version'))
require File.expand_path(File.join(__FILE__, '../sunstone/connection'))
require File.expand_path(File.join(__FILE__, '../sunstone/exception'))

require File.expand_path(File.join(__FILE__, '../arel/visitors/sunstone'))
require File.expand_path(File.join(__FILE__, '../arel/collectors/sunstone'))

require File.expand_path(File.join(__FILE__, '../active_record/connection_adapters/sunstone_adapter'))

require File.expand_path(File.join(__FILE__, '../../ext/active_record/statement_cache'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/relation'))
# require File.expand_path(File.join(__FILE__, '../../ext/active_record/relation/predicate_builder'))
# require File.expand_path(File.join(__FILE__, '../../ext/active_record/calculations'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/query_methods'))
# require File.expand_path(File.join(__FILE__, '../../ext/active_record/associations/builder/has_and_belongs_to_many'))

require File.expand_path(File.join(__FILE__, '../../ext/arel/select_manager'))
require File.expand_path(File.join(__FILE__, '../../ext/arel/nodes/eager_load'))
require File.expand_path(File.join(__FILE__, '../../ext/arel/nodes/select_statement'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/finder_methods'))
require File.expand_path(File.join(__FILE__, '../../ext/active_record/batches'))