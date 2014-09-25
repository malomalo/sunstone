module ActiveRecord
  module Batches

    private

    # "#{quoted_table_name}.#{quoted_primary_key} ASC"
    def batch_order
      {:id => :asc}
    end

  end
end
