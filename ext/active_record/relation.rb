# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

module ActiveRecord
  class Relation

    def to_sar
      @to_sar ||= begin
        if eager_loading?
          apply_join_dependency do |relation, join_dependency|
            relation = join_dependency.apply_column_aliases(relation)
            relation.to_sar
          end
        else
          conn = klass.connection
          conn.unprepared_statement { conn.to_sar(arel) }
        end
      end
    end

  end
end
