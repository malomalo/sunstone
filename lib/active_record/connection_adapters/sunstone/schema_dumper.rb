# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module ColumnDumper

        # Adds +:array+ option to the default set
        def prepare_column_options(column)
          spec = super
          spec[:array] = 'true' if column.array?
          spec
        end

      end
    end
  end
end