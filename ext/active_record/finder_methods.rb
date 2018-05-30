module Arel
  module Visitors
    class ToSql < Arel::Visitors::Reduce
      
      def visit_Arel_Attributes_Relation o, collector
        visit(o.relation, collector)
      end
      
    end
  end
end

module ActiveRecord
  class PredicateBuilder # :nodoc:

    def expand_from_hash(attributes)
      return ["1=0"] if attributes.empty?
  
      attributes.flat_map do |key, value|
        if value.is_a?(Hash)
          ka = associated_predicate_builder(key).expand_from_hash(value)
          if self.table.instance_variable_get(:@klass).connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
            ka.each { |k|
              if k.left.is_a?(Arel::Attributes::Attribute) || k.left.is_a?(Arel::Attributes::Relation)
                k.left = Arel::Attributes::Relation.new(k.left, key)
              end
            }
          end
          ka
        else
          build(table.arel_attribute(key), value)
        end
      end
    end

  end
end

module ActiveRecord
  module FinderMethods

    class SunstoneJoinDependency
      def initialize(klass)
        @klass = klass
      end
      
      def reflections
        []
      end
      
      def instantiate(result_set, &block)
        seen = Hash.new { |i, object_id|
          i[object_id] = Hash.new { |j, child_class|
            j[child_class] = {}
          }
        }

        model_cache = Hash.new { |h, klass| h[klass] = {} }
        parents = model_cache[@klass]

        message_bus = ActiveSupport::Notifications.instrumenter

        payload = {
          record_count: result_set.length,
          class_name: @klass.name
        }

        message_bus.instrument("instantiation.active_record", payload) do
          result_set.each { |row_hash|
            parent_key = @klass.primary_key ? row_hash[@klass.primary_key] : row_hash
            parent = parents[parent_key] ||= @klass.instantiate(row_hash.select{|k,v| @klass.column_names.include?(k.to_s) }, &block)
            construct(parent, row_hash.select{|k,v| !@klass.column_names.include?(k.to_s) }, seen, model_cache)
          }
        end

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
              construct(model, attributes.select{|k,v| !model.class.column_names.include?(k.to_s) }, seen, model_cache)
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
        model = seen[parent.object_id][klass][id]

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
          seen[parent.object_id][model.class.base_class][id] = model
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

    def apply_join_dependency(eager_loading: true)
      if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        join_dependency = SunstoneJoinDependency.new(base_class)
        relation = except(:includes, :eager_load, :preload)
        relation.arel.eager_load = Arel::Nodes::EagerLoad.new(eager_load_values)
      else
        join_dependency = construct_join_dependency
        relation = except(:includes, :eager_load, :preload).joins!(join_dependency)
      end

      if eager_loading && !using_limitable_reflections?(join_dependency.reflections)
        if has_limit_or_offset?
          limited_ids = limited_ids_for(relation)
          limited_ids.empty? ? relation.none! : relation.where!(primary_key => limited_ids)
        end
        relation.limit_value = relation.offset_value = nil
      end

      if block_given?
        if !connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          relation._select!(join_dependency.aliases.columns)
        end
        yield relation, join_dependency
      else
        relation
      end
    end
  end

end
