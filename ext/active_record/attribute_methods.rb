# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 9269f634d471ad6ca46752421eabd3e1c26220b5

module ActiveRecord
  module AttributeMethods

    protected

    # Returns a Hash of the Arel::Attributes and attribute values that have been
    # typecasted for use in an Arel insert/update method.
    def attributes_with_values(attribute_names)
      attrs = attribute_names.index_with { |name| @attributes[name] }

      if self.sunstone?
        self.class.reflect_on_all_associations.each do |reflection|
          if reflection.belongs_to?
            if association(reflection.name).loaded? && association(reflection.name).target == Thread.current[:sunstone_updating_model]
              attrs.delete(reflection.foreign_key)
            else
              add_attributes_for_belongs_to_association(reflection, attrs)
            end
          elsif reflection.has_one?
            add_attributes_for_has_one_association(reflection, attrs)
          elsif reflection.collection?
            add_attributes_for_collection_association(reflection, attrs, self.class.arel_table)
          end
        end
      end

      attrs
    end

    def add_attributes_for_belongs_to_association(reflection, attrs)
      key = :"add_attributes_for_belongs_to_association_#{reflection.name}"
      @_already_called ||= {}
      return if @_already_called[key]
      @_already_called[key]=true
      @_already_called[:"autosave_associated_records_for_#{reflection.name}"] = true

      association = association_instance_get(reflection.name)
      record      = association && association.load_target
      if record && !record.destroyed?
        autosave = reflection.options[:autosave]

        if autosave && record.marked_for_destruction?
          self[reflection.foreign_key] = nil
          record.destroy
        elsif autosave != false
          if record.new_record? || (autosave && record.changed_for_autosave?)
            attrs["#{reflection.name}_attributes"] = record.send(:attributes_with_values, record.new_record? ? (record.attribute_names - ['id']) : record.attribute_names)
          end
        end
      end
    end

    def add_attributes_for_has_one_association(reflection, attrs)
      key = :"add_attributes_for_has_one_association#{reflection.name}"
      @_already_called ||= {}
      return if @_already_called[key]
      @_already_called[key]=true
      @_already_called[:"autosave_associated_records_for_#{reflection.name}"] = true

      association = association_instance_get(reflection.name)
      record      = association && association.load_target

      if record && !record.destroyed?
        autosave = reflection.options[:autosave]

        if autosave && record.marked_for_destruction?
          record.destroy
        elsif autosave != false
          key = reflection.options[:primary_key] ? send(reflection.options[:primary_key]) : id

          if (autosave && record.changed_for_autosave?) || new_record? || record_changed?(reflection, record, key)
            unless reflection.through_reflection
              record[reflection.foreign_key] = key
            end

            attrs["#{reflection.name}_attributes"] = record.send(:attributes_with_values, record.new_record? ? (record.attribute_names - ['id']): record.attribute_names)
          end
        end
      end
    end

    def add_attributes_for_collection_association(reflection, attrs, arel_table=nil)
      key = :"add_attributes_for_collection_association#{reflection.name}"
      @_already_called ||= {}
      return if @_already_called[key]
      @_already_called[key]=true
      @_already_called[:"autosave_associated_records_for_#{reflection.name}"] = true
      if reflection.is_a?(ActiveRecord::Reflection::HasAndBelongsToManyReflection)
        @_already_called[:"autosave_associated_records_for_#{self.class.name.downcase.pluralize}_#{reflection.name}"] = true
      end

      if association = association_instance_get(reflection.name)
        if new_record? || (association.instance_variable_defined?(:@sunstone_changed) && association.instance_variable_get(:@sunstone_changed)) || association.target.any?(&:changed_for_autosave?) || association.target.any?(&:new_record?)
          attrs["#{reflection.name}_attributes"] = if association.target.empty?
            []
          else
            association.target.select { |r| !r.destroyed? }.map do |record|
              record.send(
                :attributes_with_values,
                record.new_record? ?
                  record.send(:attribute_names_for_partial_inserts)
                  :
                  record.send(:attribute_names_for_partial_updates) + [record.class.primary_key]
                )
            end
          end

          association.instance_variable_set(:@sunstone_changed, false)
        end

        # reconstruct the scope now that we know the owner's id
        association.reset_scope if association.respond_to?(:reset_scope)
      end
    end

  end
end
