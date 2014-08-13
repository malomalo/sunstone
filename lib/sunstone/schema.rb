require 'sunstone/type/value'
require 'sunstone/type/mutable'
require 'sunstone/type/boolean'
require 'sunstone/type/date_time'
require 'sunstone/type/decimal'
require 'sunstone/type/integer'
require 'sunstone/type/string'

module Sunstone
  class Schema
    
    attr_accessor :attributes
    
    def initialize
      @attributes = {}
    end
    
    def attribute(name, type, options = {})
      types = Sunstone::Type::Value.subclasses
      type = types.find {|sc| sc.name.demodulize.downcase == type.to_s}
      
      @attributes[name.to_s] = type.new(options)
    end
    
    def [](name)
      @attributes[name.to_s]
    end
    
    Sunstone::Type::Value.subclasses.each do |type|
      class_eval <<-EOV, __FILE__, __LINE__ + 1
        def #{type.name.demodulize.downcase}(name, options = {})
          attribute(name, "#{type.name.demodulize.downcase}", options)
        end
      EOV
    end
    
  end
end