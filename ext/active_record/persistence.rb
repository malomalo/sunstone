module ActiveRecord
  # = Active Record \Persistence
  module Persistence
    
    module ClassMethods
      def rpc(name)
        define_method("#{name}!") do
          req = Net::HTTP::Post.new("/#{self.class.table_name}/#{CGI.escape(id.to_s)}/#{CGI.escape(name.to_s)}")
          self.class.connection.send(:with_raw_connection) do |conn|
            conn.send_request(req) do |response|
              JSON.parse(response.body).each do |k,v|
                if self.class.column_names.include?(k)
                  @attributes.write_from_database(k, v)
                end
              end
            end
          end
          true
        end
      end
    end

    # Updates the attributes of the model from the passed-in hash and saves the
    # record, all wrapped in a transaction. If the object is invalid, the saving
    # will fail and false will be returned.
    def update(attributes)
      @sunstone_updating = :updating
      Thread.current[:sunstone_updating_model] = self

      # The following transaction covers any possible database side-effects of the
      # attributes assignment. For example, setting the IDs of a child collection.
      with_transaction_returning_status do
        assign_attributes(attributes)
        save
      end
    ensure
      @sunstone_updating = false
      Thread.current[:sunstone_updating_model] = nil
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

      @sunstone_updating = new_record? ? :creating : :updating
      Thread.current[:sunstone_updating_model] = self

      result = new_record? ? _create_record(&block) : _update_record(&block)

      if self.sunstone? && result != 0
        row_hash = result[0]

        seen = Hash.new { |h, parent_klass|
          h[parent_klass] = Hash.new { |i, parent_id|
            i[parent_id] = Hash.new { |j, child_klass| j[child_klass] = {} }
          }
        }

        model_cache = Hash.new { |h,klass| h[klass] = {} }
        parents = model_cache[self.class.base_class]
        
        row_hash.each do |key, value|
          if self.class.column_names.include?(key.to_s)
            _write_attribute(key, value)
          else
            assc = association(key.to_sym)
            assc.reset if assc.reflection.collection? # TODO: can load here if included
          end
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
      @sunstone_updating = false
      Thread.current[:sunstone_updating_model] = nil
    end

    # Creates a record with values matching those of the instance attributes
    # and returns its id.
    def _create_record(attribute_names = self.attribute_names)
      attribute_names = attributes_for_create(attribute_names)
      attribute_values = attributes_with_values(attribute_names)
      returning_values = nil
      
      self.class.with_connection do |connection|
        returning_columns = self.class._returning_columns_for_insert(connection)

        returning_values = self.class._insert_record(
          connection,
          attribute_values,
          returning_columns
        )

        if !self.sunstone?
          returning_columns.zip(returning_values).each do |column, value|
            _write_attribute(column, value) if !_read_attribute(column)
          end if returning_values
        end
      end

      @new_record = false
      @previously_new_record = true
      
      yield(self) if block_given?
      
      if self.sunstone?
        returning_values
      else
        id
      end
    end

    def _update_record(attribute_names = self.attribute_names)
      attribute_names = attributes_for_update(attribute_names)
      attribute_values = attributes_with_values(attribute_names)

      if attribute_values.empty?
        affected_rows = 0
        @_trigger_update_callback = true
      else
        affected_rows = self.class._update_record(attribute_values, _query_constraints_hash)
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