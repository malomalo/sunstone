module Arel
  module Nodes
    class SelectStatement < Arel::Nodes::Node

      attr_accessor :eager_load

      def initialize_with_eager_load cores = [SelectCore.new]
        initialize_without_eager_load
        @eager_load = nil
      end

      alias_method :initialize_without_eager_load, :initialize
      alias_method :initialize, :initialize_with_eager_load

      def hash
        [@cores, @orders, @limit, @lock, @offset, @with, @eager_load].hash
      end

      def eql_with_eager_load? other
        eql_without_eager_load?(other) && self.eager_load == other.eager_load
      end
      alias_method :eql_without_eager_load?, :eql?
      alias_method :eql?, :eql_with_eager_load?
      alias_method :==, :eql?

    end
  end
end
