module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class Array < ActiveRecord::Type::Value
          include ActiveRecord::Type::Helpers::Mutable
          
          attr_reader :subtype
          delegate :type, :user_input_in_time_zone, :limit, to: :subtype
          
          def initialize(subtype)
            @subtype = subtype
          end
          
          def deserialize(value)
            if value.is_a?(String)
              type_cast_array(JSON.parse(value), :deserialize)
            else
              super
            end
          end
          
          def cast(value)
            if value.is_a?(::String)
              value = JSON.parse(value)
            end
            type_cast_array(value, :cast)
          end
          
          def serialize(value)
            if value.is_a?(::Array)
              type_cast_array(value, :serialize).to_json
            else
              super
            end
          end
          
          def ==(other)
            other.is_a?(Array) && subtype == other.subtype
          end
          
          # def type_cast_for_schema(value)
          #   return super unless value.is_a?(::Array)
          #   "[" + value.map { |v| subtype.type_cast_for_schema(v) }.join(", ") + "]"
          # end
          
          def map(value, &block)
            value.map(&block)
          end
          
          # def cast_value(string)
          #   return string unless string.is_a?(::String)
          #   return if string.empty?
          #
          #   JSON.parse(string)
          # end
          
          private
          
          def type_cast_array(value, method)
            if value.is_a?(::Array)
              value.map { |item| type_cast_array(item, method) }
            else
              @subtype.public_send(method, value)
            end
          end
         
        end
      end
    end
  end
end
