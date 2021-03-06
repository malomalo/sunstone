module ActiveRecord
  # = Active Record \Persistence
  module Persistence
    
    module ClassMethods
      def rpc(name)
        define_method("#{name}!") do
          req = Net::HTTP::Post.new("/#{self.class.table_name}/#{CGI.escape(id.to_s)}/#{CGI.escape(name.to_s)}")
          self.class.connection.instance_variable_get(:@connection).send_request(req) do |response|
            JSON.parse(response.body).each do |k,v|
              if self.class.column_names.include?(k)
                @attributes.write_from_database(k, v)
              end
            end
          end
          true
        end
      end
    end
    
    def update!(attributes)
      @no_save_transaction = true
      with_transaction_returning_status do
        assign_attributes(attributes)
        save!
      end
    ensure
      @no_save_transaction = false
    end
    
    private

    def create_or_update(**, &block)
      _raise_readonly_record_error if readonly?
      return false if destroyed?
      
      @updating = new_record? ? :creating : :updating
      Thread.current[:sunstone_updating_model] = self

      result = new_record? ? _create_record(&block) : _update_record(&block)

      if self.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && result != 0
        row_hash = result.rows.first

        seen = Hash.new { |h, parent_klass|
          h[parent_klass] = Hash.new { |i, parent_id|
            i[parent_id] = Hash.new { |j, child_klass| j[child_klass] = {} }
          }
        }

        model_cache = Hash.new { |h,klass| h[klass] = {} }
        parents = model_cache[self.class.base_class]
        
        self.assign_attributes(row_hash.select{|k,v| self.class.column_names.include?(k.to_s) })
        row_hash.select{|k,v| !self.class.column_names.include?(k.to_s) }.each do |relation_name, value|
          assc = association(relation_name.to_sym)
          assc.reset if assc.reflection.collection?
        end

        construct(self, row_hash.select{|k,v| !self.class.column_names.include?(k.to_s) }, seen, model_cache)
      end

      result != false
    # TODO: perhaps this can go further down the stack?
    rescue Sunstone::Exception::BadRequest, Sunstone::Exception::Forbidden => e
      JSON.parse(e.message)['errors'].each do |field, message|
        if message.is_a?(Array)
          message.each { |m| errors.add(field, m) }
        else
          errors.add(field, message)
        end
      end
      raise ActiveRecord::RecordInvalid
    ensure
      @updating = false
      Thread.current[:sunstone_updating_model] = nil
    end
    
    # Creates a record with values matching those of the instance attributes
    # and returns its id.
    def _create_record(attribute_names = self.attribute_names)
      attribute_names &= self.class.column_names
      attributes_values = attributes_with_values(attribute_names)

      new_id = self.class._insert_record(attributes_values)

      @new_record = false
      
      if self.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
        new_id
      else
        self.id ||= new_id if self.class.primary_key
        id
      end
    end
    
    def _update_record(attribute_names = self.attribute_names)
      attribute_values = attributes_with_values(attribute_names)

      if attribute_values.empty?
        affected_rows = 0
        @_trigger_update_callback = true
      else
        affected_rows = self.class._update_record( attribute_values, self.class.primary_key => id_in_database )
        @_trigger_update_callback = affected_rows == 1
      end

      @previously_new_record = false

      yield(self) if block_given?

      affected_rows
    end

    #!!!! TODO: I am duplicated from finder_methods.....
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
    
    #!!!! TODO: I am duplicated from finder_methods.....
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

    #!!!! TODO: I am duplicated from finder_methods.....
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