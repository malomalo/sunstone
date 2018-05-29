module ActiveRecord
  module Associations
    class Association #:nodoc:

      def skip_statement_cache?(scope)
        return true if !klass.connection.supports_statement_cache?
        
        reflection.has_scope? ||
          scope.eager_loading? ||
          klass.scope_attributes? ||
          reflection.source_reflection.active_record.default_scopes.any?
      end


    end
  end
end
