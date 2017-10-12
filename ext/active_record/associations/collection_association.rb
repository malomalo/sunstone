module ActiveRecord
  module Associations
    class CollectionAssociation

      def replace(other_array)
        other_array.each { |val| raise_on_type_mismatch!(val) }
        original_target = load_target.dup

        if owner.new_record?
          replace_records(other_array, original_target)
        elsif owner.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && owner.instance_variable_defined?(:@updating) && owner.instance_variable_get(:@updating)
          replace_common_records_in_memory(other_array, original_target)

          # Remove from target
          records_for_removal = (original_target - other_array)
          if !records_for_removal.empty?
            self.instance_variable_set(:@sunstone_changed, true)
            records_for_removal.each { |record| callback(:before_remove, record) }
            records_for_removal.each { |record| target.delete(record) }
            records_for_removal.each { |record| callback(:after_remove, record) }
          end

          # Add to target
          records_for_addition = (other_array - original_target)
          if !records_for_addition.empty?
            self.instance_variable_set(:@sunstone_changed, true)
            (other_array - original_target).each do |record|
              add_to_target(record)
            end
          end

          other_array
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

    class HasManyAssociation

      def insert_record(record, validate = true, raise = false)
        set_owner_attributes(record)
        set_inverse_instance(record)

        if record.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && (!owner.instance_variable_defined?(:@updating) && owner.instance_variable_get(:@updating))
          true
        elsif raise
          record.save!(:validate => validate)
        else
          record.save(:validate => validate)
        end
      end

      private
      def save_through_record(record)
        return if record.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        build_through_record(record).save!
      ensure
        @through_records.delete(record.object_id)
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
      @updating = :updating
      Thread.current[:sunstone_updating_model] = self
      
      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes)
        save
      end
    ensure
      @updating = false
      Thread.current[:sunstone_updating_model] = nil
    end
    
  end
end
