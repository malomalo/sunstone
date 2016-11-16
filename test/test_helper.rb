# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'simplecov'
SimpleCov.start do
  add_group 'lib', 'sunstone/lib'
  add_group 'ext', 'sunstone/ext'
end

require 'rgeo'
require 'byebug'
require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'webmock/minitest'
require 'mocha/mini_test'

require 'sunstone'
require File.expand_path('../models.rb', __FILE__)



# require 'faker'
# require "mocha"
# require "mocha/mini_test"
# require 'active_support/testing/time_helpers'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# File 'lib/active_support/testing/declarative.rb', somewhere in rails....
class Minitest::Test
  
#  include ActiveSupport::Testing::TimeHelpers
  
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    defined = instance_method(test_name) rescue false
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        flunk "No implementation provided for #{name}"
      end
    end
  end
  
  def pack(data)
    
  end
  
  def unpack(data)
    MessagePack.unpack(CGI::unescape(data))
  end

  def deep_transform_query(object)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[key.to_s] = deep_transform_query(value)
      end
    when Array
      object.map {|e| deep_transform_query(e) }
    when Symbol
      object.to_s
    else
      object
    end
  end
  
  def webmock(method, path, query=nil)
    query = deep_transform_query(query) if query

    stub_request(method, /^#{ExampleRecord.connection.instance_variable_get(:@connection).url}/).with do |req|
      if query
        req&.uri&.path == path && req.uri.query && unpack(req.uri.query.sub(/=true$/, '')) == query
      else
        req&.uri&.path == path && req.uri.query.nil?
      end
    end
  end
  
  # test/unit backwards compatibility methods
  alias :assert_raise :assert_raises
  alias :assert_not_empty :refute_empty
  alias :assert_not_equal :refute_equal
  alias :assert_not_in_delta :refute_in_delta
  alias :assert_not_in_epsilon :refute_in_epsilon
  alias :assert_not_includes :refute_includes
  alias :assert_not_instance_of :refute_instance_of
  alias :assert_not_kind_of :refute_kind_of
  alias :assert_no_match :refute_match
  alias :assert_not_nil :refute_nil
  alias :assert_not_operator :refute_operator
  alias :assert_not_predicate :refute_predicate
  alias :assert_not_respond_to :refute_respond_to
  alias :assert_not_same :refute_same
  
end