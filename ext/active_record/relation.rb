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
                    binds = connection.prepare_binds_for_database(arel.bind_values + relation.bound_attributes)
                    binds.map! { |bv| connection.quote(bv) }
                    collect = visitor.accept(arel.ast, Arel::Collectors::Bind.new)
                    collect.substitute_binds(binds).join
                  end
    end
    
    
  end
end