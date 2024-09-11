# The last ref that this code was synced with Rails
# ref: 9269f634d471ad6ca46752421eabd3e1c26220b5

module ActiveRecord
  module Calculations

    def pluck(*column_names)
      if @none
        if @async
          return Promise::Complete.new([])
        else
          return []
        end
      end

      if loaded? && all_attributes?(column_names)
        result = records.pluck(*column_names)
        if @async
          return Promise::Complete.new(result)
        else
          return result
        end
      end

      if has_include?(column_names.first)
        relation = apply_join_dependency
        relation.pluck(*column_names)
      elsif klass.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        load
        return records.pluck(*column_names.map{|n| n.to_s.sub(/^#{klass.table_name}\./, "")})
      else
        klass.disallow_raw_sql!(flattened_args(column_names))
        columns = arel_columns(column_names)
        relation = spawn
        relation.select_values = columns
        result = skip_query_cache_if_necessary do
          if where_clause.contradiction?
            ActiveRecord::Result.empty(async: @async)
          else
            klass.with_connection do |c|
              c.select_all(relation.arel, "#{klass.name} Pluck", async: @async)
            end
          end
        end
        result.then do |result|
          type_cast_pluck_values(result, columns)
        end
      end
    end

  end
end