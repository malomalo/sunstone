module ActiveRecord
  module ConnectionAdapters
    module Sunstone

      module SchemaStatements

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will only find tables within
        # the current schema search path (regardless of permissions to access tables in other schemas)
        def table_exists?(name)
          schema_definition[name] != nil
        end

        # Returns the list of all column definitions for a table.
        def columns(table_name)
          # Limit, precision, and scale are all handled by the superclass.
          column_definitions(table_name).map do |column_name, options|
            new_column(column_name, lookup_cast_type(options['type']), options)
          end
        end

        # Returns the list of a table's column names, data types, and default values.
        #
        # Query implementation notes:
        #  - format_type includes the column size constraint, e.g. varchar(50)
        #  - ::regclass is a function that gives the id for a table name
        def column_definitions(table_name) # :nodoc:
          definition = schema_definition[table_name]
          raise ActiveRecord::StatementInvalid, "Table \"#{table_name}\" does not exist" if definition.nil?

          definition
        end
        
        def schema_definition
          exec( Arel::Table.new(:schema).project )
        end
    
        def tables
          Wankel.parse(@connection.get('/schema').body, :symbolize_keys => true).keys
        end
        
        def new_column(name, cast_type, options={}) # :nodoc:
          SunstoneColumn.new(name, cast_type, options)
        end
        
        def column_name_for_operation(operation, node) # :nodoc:
          visitor.accept(node, collector).first[operation.to_sym]
        end

        # TODO: def encoding

        # Returns just a table's primary key
        def primary_key(table)
          columns(table).find{ |c| c.primary_key? }.name
        end

        # TODO: do we need this?
        # Maps logical Rails types to PostgreSQL-specific data types.
        # def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        #   case type.to_s
        #   when 'binary'
        #     # PostgreSQL doesn't support limits on binary (bytea) columns.
        #     # The hard limit is 1Gb, because of a 32-bit size field, and TOAST.
        #     case limit
        #     when nil, 0..0x3fffffff; super(type)
        #     else raise(ActiveRecordError, "No binary type has byte size #{limit}.")
        #     end
        #   when 'text'
        #     # PostgreSQL doesn't support limits on text columns.
        #     # The hard limit is 1Gb, according to section 8.3 in the manual.
        #     case limit
        #     when nil, 0..0x3fffffff; super(type)
        #     else raise(ActiveRecordError, "The limit on text can be at most 1GB - 1byte.")
        #     end
        #   when 'integer'
        #     return 'integer' unless limit
        #
        #     case limit
        #       when 1, 2; 'smallint'
        #       when 3, 4; 'integer'
        #       when 5..8; 'bigint'
        #       else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
        #     end
        #   when 'datetime'
        #     return super unless precision
        #
        #     case precision
        #       when 0..6; "timestamp(#{precision})"
        #       else raise(ActiveRecordError, "No timestamp type has precision of #{precision}. The allowed range of precision is from 0 to 6")
        #     end
        #   else
        #     super
        #   end
        # end

      end
    end
  end
end
