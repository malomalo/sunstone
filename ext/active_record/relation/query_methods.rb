module ActiveRecord
  module QueryMethods
    private

    def assert_modifiable!
      raise UnmodifiableRelation if @loaded
      raise UnmodifiableRelation if @arel && !model.sunstone?
    end

  end
end