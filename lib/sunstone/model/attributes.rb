module Sunstone
  class Model
    
    class SchemaDefiner
  
      attr_reader :defined_attributes
  
      def initialize(schema)
        @schema = schema
        @defined_attributes = []
      end
  
      def attribute(name, type, options = {})
        @schema.attribute(name, type, options)
        @defined_attributes << name
      end
  
      Sunstone::Type::Value.subclasses.each do |type|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{type.name.demodulize.downcase}(name, options = {})
            attribute(name, "#{type.name.demodulize.downcase}", options)
          end
        EOV
      end
  
    end
    
    module Attributes
      
      extend ActiveSupport::Concern
      
      attr_accessor :attributes
      
      def initialize(*)
        @attributes = {}
      end
      
      def schema
        self.class.schema
      end
      
      module ClassMethods
        
        def inherited(subclass)
          super
          subclass.initialize_schema
        end
  
        def initialize_schema
          @schema = Sunstone::Schema.new
          attribute(:id, :integer)
        end
  
        def schema
          @schema
        end
        
        def define_schema(&block)
          definer = SchemaDefiner.new(@schema)
          definer.instance_eval(&block)
    
          definer.defined_attributes.each do |name|
            define_attribute_reader(name, @schema[name])
            define_attribute_writer(name, @schema[name])
          end
        end
  
        def attribute(name, type, options = {})
          attribute = @schema.attribute(name, type, options)
    
          define_attribute_reader(name, attribute)
          define_attribute_writer(name, attribute)
        end
  
        def define_attribute_reader(name, type)
          class_eval <<-EOV, __FILE__, __LINE__ + 1
            def #{name}
              @attributes[:#{name}]
            end
          EOV
        end
  
        def define_attribute_writer(name, type)
          class_eval <<-EOV, __FILE__, __LINE__ + 1
            def #{name}=(value)
              @attributes[:#{name}] = schema[:#{name}].type_cast_from_user(value)
            end
          EOV
        end

      end
      
    end
  end
end