module Sunstone
  module Type
    class Integer < Value
    
      private
    
      def _cast_value(value)
        case value
        when true then 1
        when false then 0
        else value.to_i
        end
      end
      
    end
  end
end