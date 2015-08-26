module ActiveRecord
  class StatementCache
    class PartialQuery
      
      def initialize collector
        @collector = collector
        @indexes = collector.value.find_all { |thing|
          Arel::Nodes::BindParam === thing
        }
      end

      def sql_for(binds, connection)
        binds = binds.dup
        @collector.compile(binds)
      end
    end

    def self.partial_query(visitor, ast, collector)
      collected = visitor.accept(ast, collector)
      PartialQuery.new collected
    end

  end
end
