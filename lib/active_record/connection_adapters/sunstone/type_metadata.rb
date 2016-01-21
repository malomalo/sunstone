module ActiveRecord
  module ConnectionAdapters
    class SunstoneSQLTypeMetadata < DelegateClass(SqlTypeMetadata)
      attr_reader :array

      def initialize(type_metadata, options = {})
        super(type_metadata)
        @type_metadata = type_metadata
        @primary_key = (options['primary_key'] == true)
        @array = !!options['array']
      end

    end
  end
end
