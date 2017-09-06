module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class DateTime < ActiveRecord::Type::DateTime
          
          def serialize(value)
            super(value).iso8601(ActiveSupport::JSON::Encoding.time_precision) if value
          end
          
          def cast_value(string)
            return string unless string.is_a?(::String)
            return if string.empty?

            ::DateTime.iso8601(string) || fast_string_to_time(string) || fallback_string_to_time(string)
          end
         
        end
      end
    end
  end
end