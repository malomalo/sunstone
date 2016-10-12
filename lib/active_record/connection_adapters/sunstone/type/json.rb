module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class Json < ActiveRecord::Type::Internal::AbstractJson


          def deserialize(value)
            value.dup
          end
          
          def serialize(value)
            value
          end

        end
      end
    end
  end
end