module ActiveRecord
  class Relation

    def to_sql
      @to_sql ||= begin
                    relation   = self
                    connection = klass.connection
                    visitor    = if connection.visitor.is_a?(Arel::Visitors::Sunstone)
                        Arel::Visitors::ToSql.new(connection)
                      else
                        connection.visitor
                      end

                    if eager_loading?
                      find_with_associations { |rel| relation = rel }
                    end

                    binds = if connection.visitor.is_a?(Arel::Visitors::Sunstone)
                      relation.arel.bind_values + relation.bound_attributes
                    else
                      relation.bound_attributes
                    end
                    binds = connection.prepare_binds_for_database(binds)
                    binds.map! { |value| connection.quote(value) }
                    collect = visitor.accept(relation.arel.ast, Arel::Collectors::Bind.new)
                    collect.substitute_binds(binds).join
                  end
    end
    

  end
end