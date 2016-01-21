require 'rgeo'

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Type
        class EWKB < ActiveRecord::Type::Value
          
          def type
            :ewkb
          end
          
          def serialize(value)
            if value
              ::RGeo::WKRep::WKBGenerator.new(hex_format: true, type_format: :ewkb, emit_ewkb_srid: true).generate(value)
            end
          end

          private
          
          def cast_value(string)
            return string unless string.is_a?(::String)

            ::RGeo::WKRep::WKBParser.new(RGeo::Geos.factory_generator, support_ewkb: true).parse(string)
          end
         
        end
      end
    end
  end
end