module ActiveRecord
  class Relation

    def to_sql
      @to_sql ||= begin
        relation   = self
        
        if eager_loading?
          apply_join_dependency { |rel, _| relation = rel }
        end

        conn = klass.connection
        conn.unprepared_statement {
          conn.to_sql(relation.arel)
        }
      end
    end

    def to_sar
      @to_sar ||= begin
        relation   = self
        
        if eager_loading?
          apply_join_dependency { |rel, _| relation = rel }
        end

        conn = klass.connection
        conn.unprepared_statement {
          conn.to_sar(relation.arel)
        }
      end
    end

  end
end
