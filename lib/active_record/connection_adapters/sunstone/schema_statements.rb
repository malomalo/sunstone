# frozen_string_literal: true

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
          # TODO move @definitions to using @schema_cache
          @definitions = {} if !defined?(@definitions)

          if @definitions[table_name]
            return @definitions[table_name]
          end

          response = with_raw_connection { |conn| conn.get("/#{table_name}/schema") }
          @definitions[table_name] = JSON.parse(response.body)
        rescue ::Sunstone::Exception::NotFound
          raise ActiveRecord::StatementInvalid, "Table \"#{table_name}\" does not exist"
        end

        # Returns the list of a table's column names, data types, and default values.
        #
        # Query implementation notes:
        #  - format_type includes the column size constraint, e.g. varchar(50)
        #  - ::regclass is a function that gives the id for a table name
        def column_definitions(table_name) # :nodoc:
          # TODO: settle on schema, I think we've switched to attributes, so
          # columns can be removed soon?
          definition(table_name)['attributes'] || definition(table_name)['columns']
        end

        # Returns the limit definition of the table (the maximum limit that can
        # be used).
        def limit_definition(table_name)
          definition(table_name)['limit'] || nil
        end

        def tables
          JSON.parse(with_raw_connection { |conn| conn.get('/tables').body })
        end

        def views
          []
        end

        def new_column(name, options)
          cast_type = lookup_cast_type(options)
          sql_type_metadata = fetch_type_metadata(cast_type, options)
          SunstoneColumn.new(name, cast_type, sql_type_metadata, options)
        end

        def lookup_cast_type(options)
          @type_map.lookup(options['type'], options.symbolize_keys)
        end

        def fetch_type_metadata(cast_type, options)
          simple_type = SqlTypeMetadata.new(
            sql_type: options['type'],
            type: cast_type.type,
            limit: cast_type.limit,
            precision: cast_type.precision,
            scale: cast_type.scale
          )
          SunstoneSQLTypeMetadata.new(simple_type, options)
        end

        def column_name_for_operation(operation, node) # :nodoc:
          visitor.accept(node, collector).first[operation.to_sym]
        end
        
        # Given a set of columns and an ORDER BY clause, returns the columns for a SELECT DISTINCT.
        # PostgreSQL, MySQL, and Oracle override this for custom DISTINCT syntax - they
        # require the order columns appear in the SELECT.
        #
        #   columns_for_distinct("posts.id", ["posts.created_at desc"])
        #
        def columns_for_distinct(columns, orders) # :nodoc:
          columns
        end

        def distinct_relation_for_primary_key(relation) # :nodoc:
          values = columns_for_distinct(
            relation.table[relation.primary_key],
            relation.order_values
          )

          limited = relation.reselect(values).distinct!
          limited_ids = select_rows(limited.arel, "SQL").map(&:last)

          if limited_ids.empty?
            relation.none!
          else
            relation.where!(relation.primary_key => limited_ids)
          end

          relation.limit_value = relation.offset_value = nil
          relation
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
