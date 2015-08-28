module ActiveRecord
  module QueryMethods
      
    def reverse_sql_order(order_query)
      order_query = [arel_table[primary_key].asc] if order_query.empty?

      order_query.flat_map do |o|
        case o
        when Arel::Nodes::Ordering
          o.reverse
        when String
          o.to_s.split(',').map! do |s|
            s.strip!
            s.gsub!(/\sasc\Z/i, ' DESC') || s.gsub!(/\sdesc\Z/i, ' ASC') || s.concat(' DESC')
          end
        else
          o
        end
      end
    end
      
  end
end