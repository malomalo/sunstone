require 'base64'

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class Binary < ActiveRecord::Type::Binary
          
          # Converts a value from database input to the appropriate ruby type. The
          # return value of this method will be returned from
          # ActiveRecord::AttributeMethods::Read#read_attribute. The default
          # implementation just calls Value#cast.
          #
          # +value+ The raw input, as provided from the database.
          def deserialize(value)
            value.nil? ? nil : Base64.strict_decode64(value)
          end
          
          # Casts a value from the ruby type to a type that the database knows
          # how to understand. The returned value from this method should be a
          # +String+, +Numeric+, +Date+, +Time+, +Symbol+, +true+, +false+, or
          # +nil+.
          def serialize(value)
            if limit && value.bytesize > limit
              raise ActiveModel::RangeError, "value is out of range for #{self.class} with limit #{limit} bytes"
            end
            Base64.strict_encode64(value)
          end

        end
      end
    end
  end
end