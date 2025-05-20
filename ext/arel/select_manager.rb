# frozen_string_literal: true

module Arel
  class SelectManager < Arel::TreeManager

    def eager_load
      @ast.eager_load
    end

    def eager_load=(eager_load)
      if eager_load.nil? || eager_load.expr.empty?
        @ast.eager_load = nil
      else
        @ast.eager_load = eager_load
      end
      self
    end

  end
end
