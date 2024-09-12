module ActiveRecord
  module QueryMethods
    private

    def assert_modifiable!
      raise UnmodifiableRelation if @loaded
      raise UnmodifiableRelation if @arel && !klass.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
    end

  end
end