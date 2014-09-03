module ActiveRecord
  class Relation
    def to_sql
      @to_sql ||= begin
                    relation   = self
                    connection = klass.connection
                    visitor    = connection.visitor
                    collector  = connection.collector

                    if eager_loading?
                      find_with_associations { |rel| relation = rel }
                    end

                    arel  = relation.arel
                    binds = (arel.bind_values + relation.bind_values).dup
                    binds.map! { |bv| connection.quote(*bv.reverse) }
                    collect = visitor.accept(arel.ast, collector)
                    if collector.is_a?(Arel::Collectors::Sunstone)
                      collect.compile(binds)
                    else
                      collect.substitute_binds(binds).join
                    end
                  end
    end
  end
end