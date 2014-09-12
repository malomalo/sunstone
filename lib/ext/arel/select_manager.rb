module Arel
  class SelectManager < Arel::TreeManager

    def includes
      @ast.includes
    end

    def includes=(includes)
      if includes.nil? || includes.expr.empty?
        @ast.includes = nil
      else
        @ast.includes = includes
      end
      self
    end

  end
end
