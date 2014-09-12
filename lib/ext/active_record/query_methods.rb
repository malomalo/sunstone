module ActiveRecord
  module QueryMethods

    def includes(*args)
      # self.eager_load_values += args
      arel.includes = Arel::Nodes::Includes.new(*args)
      self
    end
  end

end
