module ActiveRecord
  module FinderMethods
    
    def find_with_associations
      arel.eager_load = Arel::Nodes::EagerLoad.new(eager_load_values)

      if block_given?
        yield self
      else
        if ActiveRecord::NullRelation === self
          []
        else
          rows = connection.select_all(arel, 'SQL', arel.bind_values + bind_values)
          instantiate_with_associations(rows, self)
          # join_dependency.instantiate(rows, aliases)
        end
      end
    end
    
    def instantiate_with_associations(result_set, klass)
      seen = Hash.new { |h, parent_klass|
        h[parent_klass] = Hash.new { |i, parent_id|
          i[parent_id] = Hash.new { |j, child_klass| j[child_klass] = {} }
        }
      }

      model_cache = Hash.new { |h,klass| h[klass] = {} }
      parents = model_cache[self.base_class]
      
      result_set.each { |row_hash|
        parent = parents[row_hash[primary_key]] ||= instantiate(row_hash.select{|k,v| column_names.include?(k.to_s) })
        construct(parent, row_hash.select{|k,v| !column_names.include?(k.to_s) }, seen, model_cache)
      }
      
      parents.values
    end
    
    def construct(parent, relations, seen, model_cache)
      relations.each do |key, attributes|
        reflection = parent.class.reflect_on_association(key)
        next unless reflection
        
        if reflection.collection?
          other = parent.association(reflection.name)
          other.loaded!
        else
          if parent.association_cache.key?(reflection.name)
            model = parent.association(reflection.name).target
            construct(model, attributes.select{|k,v| !reflection.klass.column_names.include?(k.to_s) }, seen, model_cache)
          end
        end
        
        if !reflection.collection?
          construct_association(parent, reflection, attributes, seen, model_cache)
        else
          attributes.each do |row|
            construct_association(parent, reflection, row, seen, model_cache)
          end
        end
          
      end
    end
    
    def construct_association(parent, reflection, attributes, seen, model_cache)
      return if attributes.nil?
      
      klass = if reflection.polymorphic?
        parent.send(reflection.foreign_type).constantize.base_class
      else
        reflection.klass
      end
      id = attributes[klass.primary_key]
      model = seen[parent.class.base_class][parent.id][klass][id]
      
      if model
        construct(model, attributes.select{|k,v| !klass.column_names.include?(k.to_s) }, seen, model_cache)

        other = parent.association(reflection.name)
        
        if reflection.collection?
          other.target.push(model)
        else
          other.target = model
        end

        other.set_inverse_instance(model)
      else
        model = construct_model(parent, reflection, id, attributes.select{|k,v| klass.column_names.include?(k.to_s) }, seen, model_cache)
        seen[parent.class.base_class][parent.id][model.class.base_class][id] = model
        construct(model, attributes.select{|k,v| !klass.column_names.include?(k.to_s) }, seen, model_cache)
      end
    end
    

    def construct_model(record, reflection, id, attributes, seen, model_cache)
      klass = if reflection.polymorphic?
        record.send(reflection.foreign_type).constantize
      else
        reflection.klass
      end
      
      model = model_cache[klass][id] ||= klass.instantiate(attributes)
      other = record.association(reflection.name)

      if reflection.collection?
        other.target.push(model)
      else
        other.target = model
      end

      other.set_inverse_instance(model)
      model
    end
    
  end

end
