# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class Json < ActiveRecord::Type::Json


          def deserialize(value)
            value.nil? ? nil : value.dup
          end
          
          def serialize(value)
            value
          end

        end
      end
    end
  end
end