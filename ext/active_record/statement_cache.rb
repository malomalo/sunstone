module ActiveRecord
  class StatementCache
    class PartialQuery

      def initialize(values, sunstone=false)
        @values = values
        @indexes = if sunstone
          
        else
          values.each_with_index.find_all { |thing,i|
            Arel::Nodes::BindParam === thing
          }.map(&:last)
        end
      end

      def sql_for(binds, connection)
        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          binds.map!(&:value_for_database)
          @values
        else
          casted_binds = binds.map(&:value_for_database)
          val = @values.dup
          @indexes.each { |i| val[i] = connection.quote(casted_binds.shift) }
          val.join
        end
      end

    end

  end
end
