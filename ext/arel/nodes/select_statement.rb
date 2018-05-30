module Arel
  module Nodes
    class SelectStatement < Arel::Nodes::Node

      attr_accessor :eager_load

      def initialize cores = [SelectCore.new]
        super()
        @cores          = cores
        @orders         = []
        @limit          = nil
        @lock           = nil
        @offset         = nil
        @with           = nil
        @eager_load     = nil
      end
      
      def initialize_copy other
        super
        @cores  = @cores.map { |x| x.clone }
        @orders = @orders.map { |x| x.clone }
        @eager_load = @eager_load.map { |x| x.clone }
      end
      
      def hash
        [@cores, @orders, @limit, @lock, @offset, @with, @eager_load].hash
      end

      def eql? other
        self.class == other.class &&
          self.cores == other.cores &&
          self.orders == other.orders &&
          self.limit == other.limit &&
          self.lock == other.lock &&
          self.offset == other.offset &&
          self.with == other.with &&
          self.eager_load == other.eager_load
      end

    end
  end
end
