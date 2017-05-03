module ActiveRecord
  class Relation

    def to_sql
      @to_sql ||= begin
        relation   = self
        
        if eager_loading?
          find_with_associations { |rel| relation = rel }
        end

        conn = klass.connection
        conn.unprepared_statement {
          conn.to_sql(relation.arel, relation.bound_attributes)
        }
      end
    end

    def to_sar
      @to_sar ||= begin
        relation   = self
        
        if eager_loading?
          find_with_associations { |rel| relation = rel }
        end

        conn = klass.connection
        conn.unprepared_statement {
          conn.to_sar(relation.arel, relation.bound_attributes)
        }
      end
    end

    def _update_record(values, id, id_was) # :nodoc:
      substitutes, binds = substitute_values values
      
      scope = @klass.unscoped

      if @klass.finder_needs_type_condition?
        scope.unscope!(where: @klass.inheritance_column)
      end

      relation = scope.where(@klass.primary_key => (id_was || id))
      bvs = binds + relation.bound_attributes
      um = relation
        .arel
        .compile_update(substitutes, @klass.primary_key)
      um.table @klass.arel_table

      @klass.connection.update(
        um,
        'SQL',
        bvs,
      )
    end


  end
end
