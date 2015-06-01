module ActiveRecord
  module ConnectionAdapters
    # Sunstone-specific extensions to column definitions in a table.
    class SunstoneColumn < Column #:nodoc:
      attr_accessor :array

      def initialize(name, cast_type, options={})
        @primary_key = (options['primary_key'] == true)
        @array = !!options['array']
        if @array
          super(name, options['default'], Sunstone::Type::Array.new(cast_type), nil, options['null'])
        else
          super(name, options['default'], cast_type, nil, options['null'])
        end
      end
      
      def primary_key?
        @primary_key
      end
      
    end
  end
end
