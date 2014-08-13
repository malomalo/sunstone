module Sunstone
  module Type
    class Boolean < Value
      
      TRUE_VALUES = [true, 'true', 'TRUE'].to_set
    
      private
    
      def _cast_value(value)
        if value == ''
          nil
        else
          TRUE_VALUES.include?(value)
        end
      end
      
    end
  end
end