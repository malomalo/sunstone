module Sunstone
  module Type
    class Value
    
      attr_accessor :options
      
      def initialize(options={})
        @options = options
      end
      
      def type_cast_from_json(value)
        if @options[:array]
          value.nil? ? nil : value.map{ |v| _type_cast_from_json(v) }
        else
          _type_cast_from_json(value)
        end
      end

      def type_cast_from_user(value)
        if @options[:array]
          value.nil? ? nil : value.map{ |v| _type_cast_from_user(v) }
        else
          _type_cast_from_user(value)
        end
      end
    
      def type_cast_for_json(value)
        if @options[:array]
          value.nil? ? nil : value.map{ |v| _type_cast_for_json(v) }
        else
          _type_cast_for_json(value)
        end
      end
    
      # Determines whether a value has changed for dirty checking. +old_value+
      # and +new_value+ will always be type-cast. Types should not need to
      # override this method.
      def changed?(old_value, new_value, _new_value_before_type_cast)
        old_value != new_value
      end
    
      # Determines whether the mutable value has been modified since it was
      # read. Returns +false+ by default. This method should not need to be
      # overriden directly. Types which return a mutable value should include
      # +Type::Mutable+, which will define this method.
      def changed_in_place?(*)
        false
      end
      
      def readonly?
        @options[:readonly]
      end
    
      private
      
      # Type casts a value from json into the appropriate ruby type. Classes
      # which do not need separate type casting behavior for json and user
      # provided values should override +_cast_value+ instead.
      def _type_cast_from_json(value)
        _type_cast(value)
      end

      # Type casts a value from user input (e.g. from a setter). This value may
      # be a string from the form builder, or an already type cast value
      # provided manually to a setter.
      # 
      # Classes which do not need separate type casting behavior for json
      # and user provided values should override +_type_cast+ or +_cast_value+
      # instead.      
      def _type_cast_from_user(value)
        _type_cast(value)
      end

      # Cast a value from the ruby type to a type that the json knows how
      # to understand. The returned value from this method should be a
      # +String+, +Numeric+, +Symbol+, +true+, +false+, or +nil+      
      def _type_cast_for_json(value)
        value
      end
    
      def _type_cast(value)
        _cast_value(value) unless value.nil?
      end

      # Convenience method for types which do not need separate type casting
      # behavior for user and database inputs. Called by
      # `_type_cast_from_json` and `_type_cast_from_user` for all values except
      # `nil`.
      #
      # If you wish to catch the nil case use the `_type_cast` function
      def _cast_value(value) # :doc:
        value
      end
      
    end
  end
end
