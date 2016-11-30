module ActiveRecord
  class Relation

    def to_sql
      @to_sql ||= begin
        relation   = self
        connection = klass.connection
        visitor = if connection.visitor.is_a?(Arel::Visitors::Sunstone)
          Arel::Visitors::ToSql.new(connection)
        else
          connection.visitor
        end

        if eager_loading?
          find_with_associations { |rel| relation = rel }
        end

        binds = relation.bound_attributes
        binds = connection.prepare_binds_for_database(binds)
        binds.map! { |value| connection.quote(value) }
        collect = visitor.accept(relation.arel.ast, Arel::Collectors::Bind.new)
        collect.substitute_binds(binds).join
      end
    end

    def to_sar
      @to_sar ||= begin
        relation   = self
        connection = klass.connection
        visitor = if connection.visitor.is_a?(Arel::Visitors::ToSql)
          Arel::Visitors::Sunstone.new(connection)
        else
          connection.visitor
        end

        if eager_loading?
          find_with_associations { |rel| relation = rel }
        end

        binds = relation.bound_attributes
        binds = connection.prepare_binds_for_database(binds)
        binds.map! { |value| connection.quote(value) }
        collect = visitor.accept(relation.arel.ast, Arel::Collectors::Sunstone.new)
        collect.compile binds
      end
    end

  end
end
