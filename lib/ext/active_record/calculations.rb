module ActiveRecord
  module Calculations
    def pluck(*column_names)
      
      # column_names.map! do |column_name|
      #   if column_name.is_a?(Symbol) && attribute_alias?(column_name)
      #     attribute_alias(column_name)
      #   else
      #     column_name.to_s
      #   end
      # end

      if has_include?(column_names.first)
        construct_relation_for_association_calculations.pluck(*column_names)
      else
        relation = spawn
        relation.select_values = column_names.map { |cn|
          columns_hash.key?(cn) ? arel_table[cn] : cn
        }
        
        result = klass.connection.exec_query(relation.arel, nil, relation.arel.bind_values + bind_values)
        result.cast_values(klass.column_types)
      end
    end
    
  end
end

