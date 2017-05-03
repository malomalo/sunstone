module ActiveRecord
  class StatementCache
    class PartialQuery

      def initialize(values, sunstone=false)
        @values = values
        @indexes = if sunstone
          values.value.find_all { |thing|
            Arel::Nodes::BindParam === thing
          }
        else
          values.each_with_index.find_all { |thing,i|
            Arel::Nodes::BindParam === thing
          }.map(&:last)
        end
      end

      def sql_for(binds, connection)
        casted_binds = binds.map(&:value_for_database)
        
        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          @values.compile(binds)
        else
          val = @values.dup
          @indexes.each { |i| val[i] = connection.quote(casted_binds.shift) }
          val.join
        end
      end

    end

  end
end
