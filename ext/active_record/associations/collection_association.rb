# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3
class ActiveRecord::Associations::CollectionAssociation

  def replace(other_array)
    other_array.each { |val| raise_on_type_mismatch!(val) }
    original_target = skip_strict_loading { load_target }.dup

    if owner.new_record?
      replace_records(other_array, original_target)
    elsif owner.sunstone? && owner.instance_variable_defined?(:@sunstone_updating) && owner.instance_variable_get(:@sunstone_updating)
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

  def insert_record(record, validate = true, raise = false, &block)
    if record.sunstone? && owner.instance_variable_defined?(:@sunstone_updating) && owner.instance_variable_get(:@sunstone_updating)
      true
    elsif raise
      record.save!(validate: validate, &block)
    else
      record.save(validate: validate, &block)
    end
  end

end