module ActiveRecord
  module ConnectionAdapters
    # Sunstone-specific extensions to column definitions in a table.
    class SunstoneColumn < Column #:nodoc:
      NONE = Object.new

      attr_reader :array
      
      def initialize(name, sql_type_metadata, options={})
        @name = name.freeze
        @sql_type_metadata = sql_type_metadata
        @null = options['null']
        @default = options['default'] ? JSON.generate(options['default']) : options['default']
        @default_function = nil
        @collation = nil
        @table_name = nil
        @primary_key = (options['primary_key'] == true)
        @array = options['array']
        @auto_populated = options.has_key?('auto_populated') ? options['auto_populated'] : NONE
      end
      
      def primary_key?
        @primary_key
      end
      
      def auto_populated?
        # TODO: when retuning is working we can do the following to only
        # return autopulated fields from StandardAPI
        # @auto_populated == NONE ? @primary_key : @auto_populated
        true
      end
      
    end
  end
end
