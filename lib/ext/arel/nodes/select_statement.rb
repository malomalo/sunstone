module Arel
  module Nodes
    class SelectStatement < Arel::Nodes::Node

      attr_accessor :includes

      def initialize_with_includes cores = [SelectCore.new]
        initialize_without_includes
        @includes = nil
      end

      alias_method :initialize_without_includes, :initialize
      alias_method :initialize, :initialize_with_includes

      def hash
        [@cores, @orders, @limit, @lock, @offset, @with, @includes].hash
      end

      def eql_with_includes? other
        eql_without_includes?(other) && self.includes == other.includes
      end
      alias_method :eql_without_includes?, :eql?
      alias_method :eql?, :eql_with_includes?
      alias_method :==, :eql?

    end
  end
end
