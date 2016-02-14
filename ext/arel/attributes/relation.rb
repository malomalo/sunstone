module Arel
  module Attributes
    class Relation < Attribute
      
      attr_accessor :collection
      
      def initialize(relation, name, collection = false)
        self[:relation] = relation
        self[:name] = name
        @collection = collection
      end
      
      def able_to_type_cast?
        false
      end
      
      def table_name
        nil
      end
    end
  end
end