module Sunstone
  class Model
    
    module Associations
      
      extend ActiveSupport::Concern
      
      attr_accessor :assoications
      
      def initialize(*)
        super
        @associations = {}
      end
      
      def reflect_on_associations
        self.class.reflect_on_associations
      end
      
      module ClassMethods
        
        def inherited(subclass)
          super
          subclass.initialize_associations
        end
  
        def initialize_associations
          @associations = {}
        end
  
        def reflect_on_associations
          @associations
        end
        
        def belongs_to(name, options = {})
          @associations[name] = {
            :name => name,
            :macro => :belongs_to,
            :klass => (options[:class_name] || name).to_s.camelize.constantize,
            :foreign_key => (options[:foreign_key] || :"#{name}_id")
          }
          
          attribute(@associations[name][:foreign_key], :integer)
          define_association_reader(@associations[name])
          define_association_writer(@associations[name])
        end
        
        def has_many(name, options = {})
          @associations[name] = {
            :name => name,
            :macro => :has_many,
            :klass => (options[:class_name] || name.to_s.singularize).to_s.camelize.constantize
          }
          
          define_association_reader(@associations[name])
          define_association_writer(@associations[name])
        end
  
        def define_association_reader(association)
          # if association[:macro] == :belongs_to
            class_eval <<-EOV, __FILE__, __LINE__ + 1
              def #{association[:name]}
                @associations[:#{association[:name]}]
              end
            EOV
          # end
        end
  
        def define_association_writer(association)
          if association[:macro] == :belongs_to
            class_eval <<-EOV, __FILE__, __LINE__ + 1
              def #{association[:name]}=(value)
                self.#{association[:foreign_key]} = value.id if !value.nil?
                @associations[:#{association[:name]}] = value
              end
            EOV
          elsif association[:macro] == :has_many
            class_eval <<-EOV, __FILE__, __LINE__ + 1
              def #{association[:name]}=(value)
                @associations[:#{association[:name]}] = value
              end
            EOV
          end
        end

      end
      
    end
  end
end