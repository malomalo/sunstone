module ActiveRecord::Associations::Builder
  class HasAndBelongsToMany # :nodoc:

    def through_model
      habtm = JoinTableResolver.build lhs_model, association_name, options
      
      join_model = Class.new(lhs_model.base_class.superclass) {
        class << self;
          attr_accessor :class_resolver
          attr_accessor :name
          attr_accessor :table_name_resolver
          attr_accessor :left_reflection
          attr_accessor :right_reflection
        end

        def self.table_name
          table_name_resolver.join_table
        end

        def self.compute_type(class_name)
          class_resolver.compute_type class_name
        end

        def self.add_left_association(name, options)
          belongs_to name, options
          self.left_reflection = _reflect_on_association(name)
        end

        def self.add_right_association(name, options)
          rhs_name = name.to_s.singularize.to_sym
          belongs_to rhs_name, options
          self.right_reflection = _reflect_on_association(rhs_name)
        end

      }

      join_model.name                = "HABTM_#{association_name.to_s.camelize}"
      join_model.table_name_resolver = habtm
      join_model.class_resolver      = lhs_model
      join_model.primary_key         = nil

      join_model.add_left_association :left_side, anonymous_class: lhs_model
      join_model.add_right_association association_name, belongs_to_options(options)
      join_model
    end

  end
end