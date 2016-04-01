module ActiveRecord
  module Associations
    class CollectionAssociation

      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch!(val) }
        original_target = load_target.dup

        if owner.instance_variable_get(:@updateing)
          replace_common_records_in_memory(other_array, original_target)
          concat(other_array - original_target)
          other_array
        elsif owner.new_record?
          replace_records(other_array, original_target)
        else
          replace_common_records_in_memory(other_array, original_target)
          if other_array != original_target
            transaction { replace_records(other_array, original_target) }
          else
            other_array
          end
        end
      end

    end
  end
end

module ActiveRecord
  module Persistence
    # Updates the attributes of the model from the passed-in hash and saves the
    # record, all wrapped in a transaction. If the object is invalid, the saving
    # will fail and false will be returned.
    def update(attributes)
      @updateing = true
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes)
        save
      end
    ensure
      @updateing = false
    end
  end
end
