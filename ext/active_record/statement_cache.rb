# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

module ActiveRecord
  class StatementCache
    class PartialQuery

      def initialize(values, retryable:, sunstone: false)
        @values = values
        @indexes = if sunstone
        else
          values.each_with_index.find_all { |thing, i|
            Substitute === thing
          }.map(&:last)
        end
        @retryable = retryable
      end
      
      def sql_for(binds, connection)
        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
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
