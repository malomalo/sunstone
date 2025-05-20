# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module Quoting
        extend ActiveSupport::Concern

        module ClassMethods # :nodoc:

          # Quotes column names for use in SQL queries.
          def quote_column_name(name) # :nodoc:
            name
          end

        end

      end
    end
  end
end
