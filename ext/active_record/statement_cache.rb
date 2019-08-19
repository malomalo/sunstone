module ActiveRecord
  class StatementCache
    class PartialQuery

      def initialize(values, sunstone=false)
        @values = values
        @indexes = if sunstone
        else
          values.each_with_index.find_all { |thing, i|
            Substitute === thing
          }.map(&:last)
        end
      end

      def sql_for(binds, connection)
        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          binds.map!(&:value_for_database)
          @values
        else
          val = @values.dup
          casted_binds = binds.map(&:value_for_database)
          @indexes.each { |i| val[i] = connection.quote(casted_binds.shift) }
          val.join
        end
      end

    end

  end
end
