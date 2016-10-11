module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class Json < ActiveRecord::Type::Internal::AbstractJson

          def serialize(value)
            value
          end

        end
      end
    end
  end
end