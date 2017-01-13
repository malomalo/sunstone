module ActiveRecord
  module Calculations
    
    def pluck(*column_names)
      if loaded? && (column_names.map(&:to_s) - @klass.attribute_names - @klass.attribute_aliases.keys).empty?
        return records.pluck(*column_names)
      end

      if has_include?(column_names.first)
        construct_relation_for_association_calculations.pluck(*column_names)
      elsif klass.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        load
        return records.pluck(*column_names.map{|n| n.sub(/^#{klass.table_name}\./, "")})
      else
        relation = spawn
        relation.select_values = column_names.map { |cn|
          @klass.has_attribute?(cn) || @klass.attribute_alias?(cn) ? arel_attribute(cn) : cn
        }
        result = klass.connection.select_all(relation.arel, nil, bound_attributes)
        result.cast_values(klass.attribute_types)
      end
    end
    
  end
end