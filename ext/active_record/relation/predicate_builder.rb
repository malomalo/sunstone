# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

class ActiveRecord::PredicateBuilder # :nodoc:

  def expand_from_hash(attributes, &block)
    return [Arel.sql("1=0", retryable: true)] if attributes.empty?

    attributes.flat_map do |key, value|
      if key.is_a?(Array) && key.size == 1
        key = key.first
        value = value.flatten
      end
      
      if key.is_a?(Array)
        queries = Array(value).map do |ids_set|
          raise ArgumentError, "Expected corresponding value for #{key} to be an Array" unless ids_set.is_a?(Array)
          expand_from_hash(key.zip(ids_set).to_h)
        end
        grouping_queries(queries)
      elsif value.is_a?(Hash) && !table.has_column?(key)
        ka = table.associated_table(key, &block)
          .predicate_builder.expand_from_hash(value.stringify_keys)

        if self.table.instance_variable_get(:@klass).sunstone?
          ka.each { |k|
            if k.left.is_a?(Arel::Attributes::Attribute) || k.left.is_a?(Arel::Attributes::Relation)
              k.left = Arel::Attributes::Relation.new(k.left, key)
            end
          }
        end
        ka
      elsif (associated_reflection = table.associated_with(key))
        # Find the foreign key when using queries such as:
        # Post.where(author: author)
        #
        # For polymorphic relationships, find the foreign key and type:
        # PriceEstimate.where(estimate_of: treasure)

        if associated_reflection.polymorphic?
          value = [value] unless value.is_a?(Array)
          klass = PolymorphicArrayValue
        elsif associated_reflection.through_reflection?
          associated_table = table.associated_table(key)
          
          next associated_table.predicate_builder.expand_from_hash(
            associated_table.primary_key => value
          )
        end

        klass ||= AssociationQueryValue
        queries = klass.new(associated_reflection, value).queries.map! do |query|
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