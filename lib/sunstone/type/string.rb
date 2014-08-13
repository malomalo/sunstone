module Sunstone
  module Type
    class String < Value
    
      private
    
      def _cast_value(value)
        case value
        when true then "1"
        when false then "0"
        # Dup the string
        else ::String.new(value.to_s)
        end
      end
      
    end
  end
end