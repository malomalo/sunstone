module ActiveRecord
  module ConnectionAdapters
    # Sunstone-specific extensions to column definitions in a table.
    class SunstoneColumn < Column #:nodoc:
      delegate :array, to: :sql_type_metadata
      alias :array? :array
      
      def initialize(name, sql_type_metadata, options={})
        @name = name.freeze
        @sql_type_metadata = sql_type_metadata
        @null = options['null']
        @default = options['default']
        @default_function = nil
        @collation = nil
        @table_name = nil
        @primary_key = (options['primary_key'] == true)
      end
      
      def primary_key?
        @primary_key
      end
      
    end
  end
end
