class Wankel::SaxEncoder
  
  def value(val)
    if val.is_a?(Numeric)
      number(val)
    elsif val.is_a?(String)
      string(val)
    elsif val.nil?
      null
    elsif val == true || val == false
      boolean(val)
    elsif val.is_a?(Array)
      array_open
      val.each {|v| value(v) }
      array_close
    else
      puts 'fail'
    end
  end
  
end

module Sunstone
  class Model
    
    module Persistence
      
      extend ActiveSupport::Concern
      
      def initialize(*)
        super
        @new_record = true
      end
      
      # Returns true if this object hasn't been saved yet -- that is, a record
      # for the object doesn't exist in the database yet; otherwise, returns false.
      def new_record?
        @new_record
      end

      # Returns true if this object has been destroyed, otherwise returns false.      
      def destroyed?
        @destroyed
      end
          
      # Returns true if the record is persisted, i.e. it's not a new record and
      # it was not destroyed, otherwise returns false.
      def persisted?
        !(new_record? || destroyed?)
      end
      
      def serialize(options={})
        attrs = options[:only] || schema.attributes.keys
        
        output = StringIO.new
        encoder = Wankel::SaxEncoder.new(output)
        
        encoder.map_open
        
        attrs.each do |name|
          encoder.string  name
          encoder.value   schema[name].type_cast_for_json(self.send(name))
        end
        
        encoder.map_close
        encoder.complete
        output.string
      end
      
      def serialize_for_create_and_update
        attrs = []
        schema.attributes.each do |name, type|
          attrs << name if name != "id" && !type.readonly?
        end
      
        serialize(:only => attrs)
      end
      
      # Saves the model.
      #
      # If the model is new a record gets created, otherwise the existing record
      # gets updated.
      #
      # TODO:
      # By default, save always run validations. If any of them fail the action
      # is cancelled and +save+ returns +false+. However, if you supply
      # validate: false, validations are bypassed altogether. See
      # ActiveRecord::Validations for more information.
      #
      # TODO:
      # There's a series of callbacks associated with +save+. If any of the
      # <tt>before_*</tt> callbacks return +false+ the action is cancelled and
      # +save+ returns +false+. See ActiveRecord::Callbacks for further
      # details.
      #
      # Attributes marked as readonly are silently ignored if the record is
      # being updated.
      def save(*)
        create_or_update
      rescue Sunstone::RecordInvalid
        false
      end

      # Saves the model.
      #
      # If the model is new a record gets created, otherwise the existing record
      # gets updated.
      #
      # TODO:
      # With <tt>save!</tt> validations always run. If any of them fail
      # ActiveRecord::RecordInvalid gets raised. See ActiveRecord::Validations
      # for more information.
      #
      # TODO:
      # There's a series of callbacks associated with <tt>save!</tt>. If any of
      # the <tt>before_*</tt> callbacks return +false+ the action is cancelled
      # and <tt>save!</tt> raises ActiveRecord::RecordNotSaved. See
      # ActiveRecord::Callbacks for further details.
      #
      # Attributes marked as readonly are silently ignored if the record is
      # being updated.
      def save!(*)
        create_or_update || raise(RecordNotSaved)
      end
      
      private
      
      def create_or_update
        result = new_record? ? _create_record : _update_record
        result != false
      end
      
      def _create_record
        begin
          Sunstone.post("/#{self.class.model_name.route_key}", serialize_for_create_and_update) do |response|
            Sunstone::Parser.parse(self, response)
          end
          @new_record = false
          true
        rescue Sunstone::Exception::BadRequest => e
          Sunstone::Parser.parse(self, e.response)
          raise Sunstone::RecordInvalid
        end
      end
      
      def _update_record
        Sunstone.put("/#{self.class.model_name.route_key}/#{self.to_param}", serialize_for_create_and_update) do |response|
          Sunstone::Parser.parse(self, response)
        end
      end
      
      module ClassMethods
      
        def find(id)
          Sunstone.get("/#{self.model_name.route_key}/#{id}") do |response|
            model = Sunstone::Parser.parse(self, response)
            model.instance_variable_set(:@new_record, false)
            model
          end
        end
      
      end

      
    end
    
  end
end