module ActiveRecord
  class Relation

    def to_sql
      @to_sql ||= begin
                    relation   = self
                    connection = klass.connection
                    visitor    = connection.visitor.is_a?(Arel::Visitors::Sunstone) ? Arel::Visitors::ToSql.new(connection) : connection.visitor

                    if eager_loading?
                      find_with_associations { |rel| relation = rel }
                    end

                    arel  = relation.arel
                    binds = (arel.bind_values + relation.bind_values).dup
                    binds.map! { |bv| connection.quote(*bv.reverse) }
                    collect = visitor.accept(arel.ast, Arel::Collectors::Bind.new)
                    collect.substitute_binds(binds).join
                  end
    end
    
    
  end
end