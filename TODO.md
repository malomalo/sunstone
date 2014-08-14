- Check if `Sunstone#to_key` needs to be added

- Add `Sunstone::Model::Persistance` with the following methods:

  - `#new_record?`
  - `#persisted?`
  - `#save`
  - `#save!`
  - `#update`
  - `#update!`
  - `#create`
  - `#to_param` ?
  - `::all`
  - `::where` (probably goes in an Arel like engine)
  - `::build`
  - `::create!`
  - `#==`
  - `::create`

      ```ruby
      # Creates an object and saves it to the MLS. The resulting object is returned
      # whether or no the object was saved successfully to the MLS or not.
      #
      # ==== Examples
      #  #!ruby
      #  # Create a single new object
      #  User.create(:first_name => 'Jamie')
      #  
      #  # Create a single object and pass it into a block to set other attributes.
      #  User.create(:first_name => 'Jamie') do |u|
      #    u.is_admin = false
      #  end
      def self.create(attributes={}, &block) # TODO: testme
        model = self.new(attributes)
        yield(model) if block_given?
        model.save
        model
      end
      

- Look at https://gist.github.com/malomalo/91f360fe52db3dbe1c99 files for inspiration, came from
  Rails code I think
  
- Simplify `Sunstone::Type::Value` to `Sunstone::Type`

- Add a `find_class(type)` in `Sunstone::Schema`

- Possibly use Classes to hold information about each attribute in addition to the type

   ```ruby
   class MLS::Attribute
   
     DEFAULT_OPTIONS = { :serialize => true }
  
     attr_reader :model, :name, :instance_variable_name, :options, :default
     attr_reader :reader_visibility, :writer_visibility

     def initialize(name, options={})
       @name                   = name
       @instance_variable_name = "@#{@name}".freeze
       @options                = DEFAULT_OPTIONS.merge(options)
     
       @default = @options[:default]
       @reader_visibility = @options[:reader] || :public
       @writer_visibility = @options[:writer] || :public
     end
   end
   ```

- Use Association classes to model the association:

	```ruby
	class MLS::Association
	  class BelongsTo
	    attr_reader :klass, :foreign_key, :foreign_type, :primary_key, :polymorphic
	  
	    def initialize(name, options={})
	      @name                   = name
	      @klass = options[:class_name] ? options[:class_name].constantize : name.camelize.constantize
	    
	      @polymorphic  = options[:polymorphic]  || false    
	      @foreign_key  = options[:foreign_key]  || "#{name}_id".to_sym
	      @foreign_type = options[:foreign_type] || "#{name}_type".to_sym
	      @primary_key  = options[:primary_key]  || :id
	    end
	  end

	end
	```