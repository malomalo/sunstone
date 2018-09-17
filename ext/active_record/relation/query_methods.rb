module ActiveRecord
  module QueryMethods
    private
      def assert_mutability!
        raise ImmutableRelation if @loaded
        raise ImmutableRelation if defined?(@arel) && !klass.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && @arel
      end
  end
end