module ActiveRecord
  class StatementCache
    class PartialQuery

      def initialize(values, sunstone=false)
        @values = values
        if sunstone
          @indexes = values.value.find_all { |thing|
            Arel::Nodes::BindParam === thing
          }
        else
          @indexes = values.each_with_index.find_all { |thing,i|
            Arel::Nodes::BindParam === thing
          }.map(&:last)
        end
      end

      def sql_for(binds, connection)
        binds = binds.dup
        
        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          @values.compile(binds)
        else
          val = @values.dup
          @indexes.each { |i| val[i] = connection.quote(*binds.shift.reverse) }
          val.join
        end
      end
    end

    def self.partial_query(visitor, ast, collector)
      collected = visitor.accept(ast, collector)
      PartialQuery.new(visitor.is_a?(Arel::Visitors::Sunstone) ? collected : collected.value, visitor.is_a?(Arel::Visitors::Sunstone))
    end

  end
end
