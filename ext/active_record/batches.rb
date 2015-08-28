module ActiveRecord
  module Batches

    private

    # Arrrr Rails hard coding SQL
    def batch_order
      primary_key ? {primary_key => :asc} : {}
    end

  end
end
