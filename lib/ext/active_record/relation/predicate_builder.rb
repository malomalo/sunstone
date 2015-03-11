module ActiveRecord
  class PredicateBuilder # :nodoc:

    def self.expand(klass, table, column, value)
      queries = []

      # In standard Rails where takes :table => { columns }, but in sunstone we
      # can can do nested tables eg: where(:properties => { :regions => {:id => 1}})
      if klass && reflection = klass._reflect_on_association(column)
        if reflection.polymorphic? && base_class = polymorphic_base_class_from_value(value)
          queries << build(table[reflection.foreign_type], base_class)
        end

        # column = reflection.foreign_key
        column # Don't need Rails to assume we are referencing a table
      end

      queries << build(table[column], value)
      queries
    end

  end
end