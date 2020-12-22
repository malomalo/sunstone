module ActiveRecord
  module Calculations
    
    def pluck(*column_names)
      if loaded? && all_attributes?(column_names)
        return records.pluck(*column_names)
      end

      if has_include?(column_names.first)
        relation = apply_join_dependency
        relation.pluck(*column_names)
      elsif klass.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        load
        return records.pluck(*column_names.map{|n| n.sub(/^#{klass.table_name}\./, "")})
      else
        klass.disallow_raw_sql!(column_names)
        columns = arel_columns(column_names)
        relation = spawn
        relation.select_values = columns
        
        result = skip_query_cache_if_necessary do
          if where_clause.contradiction?
            ActiveRecord::Result.new([], [])
          else
            klass.connection.select_all(relation.arel, nil)
          end
        end
        type_cast_pluck_values(result, columns)
      end
    end

  end
end