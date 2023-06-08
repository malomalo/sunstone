# The last ref that this code was synced with Rails
# ref: 9269f634d471ad6ca46752421eabd3e1c26220b5

module ActiveRecord
  class PredicateBuilder # :nodoc:

    def expand_from_hash(attributes, &block)
      return ["1=0"] if attributes.empty?

      attributes.flat_map do |key, value|
        if value.is_a?(Hash) && !table.has_column?(key)
          ka = table.associated_table(key, &block)
            .predicate_builder.expand_from_hash(value.stringify_keys)

          if self.table.instance_variable_get(:@klass).connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
            ka.each { |k|
              if k.left.is_a?(Arel::Attributes::Attribute) || k.left.is_a?(Arel::Attributes::Relation)
                k.left = Arel::Attributes::Relation.new(k.left, key)
              end
            }
          end
          ka
        elsif table.associated_with?(key)
          # Find the foreign key when using queries such as:
          # Post.where(author: author)
          #
          # For polymorphic relationships, find the foreign key and type:
          # PriceEstimate.where(estimate_of: treasure)
          associated_table = table.associated_table(key)
          if associated_table.polymorphic_association?
            value = [value] unless value.is_a?(Array)
            klass = PolymorphicArrayValue
          elsif associated_table.through_association?
            next associated_table.predicate_builder.expand_from_hash(
              associated_table.primary_key => value
            )
          end

          klass ||= AssociationQueryValue
          queries = klass.new(associated_table, value).queries.map! do |query|
            # If the query produced is identical to attributes don't go any deeper.
            # Prevents stack level too deep errors when association and foreign_key are identical.
            query == attributes ? self[key, value] : expand_from_hash(query)
          end

          grouping_queries(queries)
        elsif table.aggregated_with?(key)
          mapping = table.reflect_on_aggregation(key).mapping
          values = value.nil? ? [nil] : Array.wrap(value)
          if mapping.length == 1 || values.empty?
            column_name, aggr_attr = mapping.first
            values = values.map do |object|
              object.respond_to?(aggr_attr) ? object.public_send(aggr_attr) : object
            end
            self[column_name, values]
          else
            queries = values.map do |object|
              mapping.map do |field_attr, aggregate_attr|
                self[field_attr, object.try!(aggregate_attr)]
              end
            end

            grouping_queries(queries)
          end
        else
          self[key, value]
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
      
      def apply_column_aliases(relation)
        relation
      end
      
      def instantiate(result_set, strict_loading_value, &block)
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
            construct(parent, row_hash.select{|k,v| !@klass.column_names.include?(k.to_s) }, seen, model_cache, strict_loading_value)
          }
        end

        parents.values
      end

      def construct(parent, relations, seen, model_cache, strict_loading_value)
        relations.each do |key, attributes|
          reflection = parent.class.reflect_on_association(key)
          next unless reflection

          if reflection.collection?
            other = parent.association(reflection.name)
            other.loaded!
          else
            if parent.association_cached?(reflection.name)
              model = parent.association(reflection.name).target
              construct(model, attributes.select{|k,v| !model.class.column_names.include?(k.to_s) }, seen, model_cache, strict_loading_value)
            end
          end

          if !reflection.collection?
            construct_association(parent, reflection, attributes, seen, model_cache, strict_loading_value)
          else
            attributes.each do |row|
              construct_association(parent, reflection, row, seen, model_cache, strict_loading_value)
            end
          end

        end
      end

      def construct_association(parent, reflection, attributes, seen, model_cache, strict_loading_value)
        return if attributes.nil?

        klass = if reflection.polymorphic?
          parent.send(reflection.foreign_type).constantize.base_class
        else
          reflection.klass
        end
        id = attributes[klass.primary_key]
        model = seen[parent.object_id][klass][id]

        if model
          construct(model, attributes.select{|k,v| !klass.column_names.include?(k.to_s) }, seen, model_cache, strict_loading_value)

          other = parent.association(reflection.name)

          if reflection.collection?
            other.target.push(model)
          else
            other.target = model
          end

          other.set_inverse_instance(model)
        else
          model = construct_model(parent, reflection, id, attributes.select{|k,v| klass.column_names.include?(k.to_s) }, seen, model_cache, strict_loading_value)
          seen[parent.object_id][model.class.base_class][id] = model
          construct(model, attributes.select{|k,v| !klass.column_names.include?(k.to_s) }, seen, model_cache, strict_loading_value)
        end
      end


      def construct_model(record, reflection, id, attributes, seen, model_cache, strict_loading_value)
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

    def apply_join_dependency(eager_loading: group_values.empty?)
      if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        join_dependency = SunstoneJoinDependency.new(base_class)
        relation = except(:includes, :eager_load, :preload)
        relation.arel.eager_load = Arel::Nodes::EagerLoad.new(eager_load_values)
      else
        join_dependency = construct_join_dependency(
          eager_load_values | includes_values, Arel::Nodes::OuterJoin
        )
        relation = except(:includes, :eager_load, :preload).joins!(join_dependency)
      end

      if eager_loading && has_limit_or_offset? && !(
          using_limitable_reflections?(join_dependency.reflections) &&
          using_limitable_reflections?(
            construct_join_dependency(
              select_association_list(joins_values).concat(
                select_association_list(left_outer_joins_values)
              ), nil
            ).reflections
          )
        )
        if !connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          relation = skip_query_cache_if_necessary do
            klass.connection.distinct_relation_for_primary_key(relation)
          end
        end
      end

      if block_given?
        yield relation, join_dependency
      else
        relation
      end
    end
    
  end

end
