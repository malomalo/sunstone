module ActiveRecord
  module ConnectionAdapters
    # Sunstone-specific extensions to column definitions in a table.
    class SunstoneColumn < Column #:nodoc:
      attr_accessor :array

      def initialize(name, cast_type, options={})
        @primary_key = (options['primary_key'] == true)
        @array = !!options['array']
        super(name, options['default'], cast_type, nil, options['null'])
      end
      
      def primary_key?
        @primary_key
      end
      
    end
  end
end
