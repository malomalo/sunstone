# The last ref that this code was synced with Rails
# ref: 9269f634d471ad6ca46752421eabd3e1c26220b5

module ActiveRecord
  module Calculations

    # Prior to Rails 8 we didn't need this method becuase it would
    # return the first value if there was just one - so we'll just
    # do the same as prevously because it doesn't have to be joined
    def select_for_count
      if select_values.empty?
        :all
      else
        with_connection do |conn|
          # Rails compiles this to a string, but we don't have string we
          # have a hash
          if model.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
            sv = arel_columns(select_values)
            sv.one? ? sv.first : sv
          else
            sv = arel_columns(select_values).map { |column| conn.visitor.compile(column) } 
            sv.one? ? sv.first : sv.join(", ")
          end
        end
      end
    end

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
      elsif model.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        load
        return records.pluck(*column_names.map{|n| n.to_s.sub(/^#{model.table_name}\./, "")})
      else
        model.disallow_raw_sql!(flattened_args(column_names))
        relation = spawn
        columns = relation.arel_columns(column_names)
        relation.select_values = columns
        result = skip_query_cache_if_necessary do
          if where_clause.contradiction?
            ActiveRecord::Result.empty(async: @async)
          else
            model.with_connection do |c|
              c.select_all(relation.arel, "#{model.name} Pluck", async: @async)
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