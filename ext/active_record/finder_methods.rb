module ActiveRecord
  module FinderMethods

    def find_with_associations
      join_dependency = nil
      aliases = nil
      relation = if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        arel.eager_load = Arel::Nodes::EagerLoad.new(eager_load_values)
        self
      else
        join_dependency = construct_join_dependency(joins_values)
        aliases  = join_dependency.aliases
        apply_join_dependency(select(aliases.columns), join_dependency)
      end
      
      if block_given?
        yield relation
      else
        if ActiveRecord::NullRelation === relation
          []
        else
          arel = relation.arel
          rows = connection.select_all(arel, 'SQL', arel.bind_values + relation.bound_attributes)
          if join_dependency
            join_dependency.instantiate(rows, aliases)
          else
            instantiate_with_associations(rows, relation)
          end
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
          if parent.association_cached?(reflection.name)
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
