module ActiveRecord
  module ConnectionAdapters
    module Sunstone

      module SchemaStatements

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will only find tables within
        # the current schema search path (regardless of permissions to access tables in other schemas)
        def table_exists?(name)
          tables.include?(name)
        end

        # Returns the list of all column definitions for a table.
        def columns(table_name)
          # Limit, precision, and scale are all handled by the superclass.
          column_definitions(table_name).map do |column_name, options|
            new_column(column_name, options)
          end
        end

        def definition(table_name)
          response = @connection.get("/#{table_name}/schema")

          version = Gem::Version.create(response['X-StandardAPI-Version'] || '5.0.0.4')

          if (version >= Gem::Version.create('5.0.0.5'))
            JSON.parse(response.body)
          else
            { 'columns' => JSON.parse(response.body), 'limit' => nil }
          end
        rescue ::Sunstone::Exception::NotFound
          raise ActiveRecord::StatementInvalid, "Table \"#{table_name}\" does not exist"
        end

        # Returns the list of a table's column names, data types, and default values.
        #
        # Query implementation notes:
        #  - format_type includes the column size constraint, e.g. varchar(50)
        #  - ::regclass is a function that gives the id for a table name
        def column_definitions(table_name) # :nodoc:
          definition(table_name)['columns']
        end

        # Returns the limit definition of the table (the maximum limit that can
        # be used).
        def limit_definition(table_name)
          definition(table_name)['limit'] || Float::INFINITY
        end

        def tables
          JSON.parse(@connection.get('/tables').body)
        end
        
        def views
          []
        end
        
        def new_column(name, options)
          sql_type_metadata = fetch_type_metadata(options)
          SunstoneColumn.new(name, sql_type_metadata, options)
        end
        
        def fetch_type_metadata(options)
          cast_type = lookup_cast_type(options['type'])
          simple_type = SqlTypeMetadata.new(
            sql_type: options['type'],
            type: cast_type.type,
            limit: cast_type.limit,
            precision: cast_type.precision,
            scale: cast_type.scale,
          )
          SunstoneSQLTypeMetadata.new(simple_type, options)
        end
        
        def column_name_for_operation(operation, node) # :nodoc:
          visitor.accept(node, collector).first[operation.to_sym]
        end

        # TODO: def encoding

        # Returns just a table's primary key
        def primary_key(table)
          columns(table).find{ |c| c.primary_key? }.try(:name)
        end

      end
    end
  end
end
