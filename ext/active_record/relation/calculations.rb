module ActiveRecord
  module Calculations
    
    def pluck(*column_names)
      if loaded? && (column_names.map(&:to_s) - @klass.attribute_names - @klass.attribute_aliases.keys).empty?
        return records.pluck(*column_names)
      end
      
      if has_include?(column_names.first)
        relation = apply_join_dependency
        relation.pluck(*column_names)
      elsif klass.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        load
        return records.pluck(*column_names.map{|n| n.to_s.sub(/^#{klass.table_name}\./, "")})
      else
        klass.disallow_raw_sql!(column_names)
        relation = spawn
        relation.select_values = column_names
        result = skip_query_cache_if_necessary { klass.connection.select_all(relation.arel, nil) }
        result.cast_values(klass.attribute_types)
      end
    end

  end
end