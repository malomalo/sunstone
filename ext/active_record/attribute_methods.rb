module ActiveRecord
  module AttributeMethods
    
    protected
    
    # Returns a Hash of the Arel::Attributes and attribute values that have been
    # typecasted for use in an Arel insert/update method.
    def arel_attributes_with_values(attribute_names)
      attrs = {}
      arel_table = self.class.arel_table
      
      attribute_names.each do |name|
        attrs[arel_table[name]] = typecasted_attribute_value(name)
      end

      if self.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        self.class.reflect_on_all_associations.each do |reflection|
          if reflection.belongs_to?
            if association(reflection.name).loaded? && association(reflection.name).target == Thread.current[:sunstone_updating_model]
              attrs.delete(arel_table[reflection.foreign_key])
            else
              add_attributes_for_belongs_to_association(reflection, attrs)
            end
          elsif reflection.has_one?
            add_attributes_for_has_one_association(reflection, attrs)
          elsif reflection.collection?
            add_attributes_for_collection_association(reflection, attrs, arel_table)
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
            if record.new_record?
              record.send(:arel_attributes_with_values_for_create, record.attribute_names).each do |k, v|
                attrs[Arel::Attributes::Relation.new(k, reflection.name, false, true)] = v
              end
            else
              record.send(:arel_attributes_with_values_for_update, record.attribute_names).each do |k, v|
                attrs[Arel::Attributes::Relation.new(k, reflection.name, false, true)] = v
              end
            end
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

            if record.new_record?
              record.send(:arel_attributes_with_values_for_create, record.attribute_names).each do |k, v|
                attrs[Arel::Attributes::Relation.new(k, reflection.name, false, true)] = v
              end
            else
              record.send(:arel_attributes_with_values_for_update, record.attribute_names).each do |k, v|
                attrs[Arel::Attributes::Relation.new(k, reflection.name, false, true)] = v
              end
            end
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
        if new_record? || (association.instance_variable_defined?(:@sunstone_changed) && association.instance_variable_get(:@sunstone_changed)) || reflection.options[:autosave] || association.target.any?(&:changed_for_autosave?) || association.target.any?(&:new_record?)
          attrs[Arel::Attributes::EmptyRelation.new(arel_table, reflection.name, true, true)] = [] if association.target.empty?
        
          association.target.each_with_index do |record, idx|
            next if record.destroyed?

            if record.new_record?
              record.send(:arel_attributes_with_values_for_create, record.send(:keys_for_partial_write) + [record.class.primary_key]).each do |k, v|
                attrs[Arel::Attributes::Relation.new(k, reflection.name, idx, true)] = v
              end
            else
              record.send(:arel_attributes_with_values_for_update, record.send(:keys_for_partial_write) + [record.class.primary_key]).each do |k, v|
                attrs[Arel::Attributes::Relation.new(k, reflection.name, idx, true)] = v
              end
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
