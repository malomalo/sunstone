module ActiveRecord
  class StatementCache
    class PartialQuery

      def initialize(values, sunstone=false)
        @values = values
        @indexes = if sunstone
        else
          values.each_with_index.find_all { |thing, i|
            Substitute === thing
          }.map(&:last)
        end
      end

      def sql_for(binds, connection)
        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          binds.map!(&:value_for_database)
          @values
        else
          val = @values.dup
          @indexes.each do |i|
            value = binds.shift
            if ActiveModel::Attribute === value
              value = value.value_for_database
            end
            val[i] = connection.quote(value)
          end
          val.join
        end
      end

    end

  end
end
