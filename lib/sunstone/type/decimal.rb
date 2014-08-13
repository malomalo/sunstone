module Sunstone
  module Type
    class Decimal < Value
    
      private
    
      def _cast_value(value)
        if value == ''
          nil
        elsif value.is_a?(BigDecimal)
          value
        else
          BigDecimal.new(value.to_s)
        end
      end
      
    end
  end
end