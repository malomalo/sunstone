require 'active_record/connection_adapters/abstract_adapter'


#require 'active_record/connection_adapters/statement_pool'

require 'active_record/connection_adapters/sunstone/database_statements'
require 'active_record/connection_adapters/sunstone/schema_statements'
require 'active_record/connection_adapters/sunstone/schema_dumper'
require 'active_record/connection_adapters/sunstone/column'

require 'active_record/connection_adapters/sunstone/type/date_time'
require 'active_record/connection_adapters/sunstone/type/array'
require 'active_record/connection_adapters/sunstone/type/uuid'
require 'active_record/connection_adapters/sunstone/type/ewkb'

module ActiveRecord
  module ConnectionHandling # :nodoc:

    VALID_SUNSTONE_CONN_PARAMS = [:url, :host, :port, :api_key, :use_ssl, :user_agent, :ca_cert]

    # Establishes a connection to the database that's used by all Active Record
    # objects
    def sunstone_connection(config)
      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]
      if conn_params[:url]
        uri = URI.parse(conn_params.delete(:url))
        conn_params[:api_key] ||= (uri.user ? CGI.unescape(uri.user) : nil)
        conn_params[:host]    ||= uri.host
        conn_params[:port]    ||= uri.port
        conn_params[:use_ssl] ||= (uri.scheme == 'https')
      end
      
      # Forward only valid config params to PGconn.connect.
      conn_params.slice!(*VALID_SUNSTONE_CONN_PARAMS)

      # The postgres drivers don't allow the creation of an unconnected PGconn object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::SunstoneAPIAdapter.new(nil, logger, conn_params, config)
    end
  end

  module ConnectionAdapters
    # The SunstoneAPI adapter.
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to a Unix-domain socket in /tmp. On machines
    #   without Unix-domain sockets, the default is to connect to localhost.
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - The API key to connect with
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO
    #   <encoding></tt> call on the connection.
    class SunstoneAPIAdapter < AbstractAdapter
      ADAPTER_NAME = 'Sunstone'.freeze

      NATIVE_DATABASE_TYPES = {
        string:      { name: "string" },
        number:      { name: "number" },
        json:        { name: "json" },
        boolean:     { name: "boolean" }
      }

      # include PostgreSQL::Quoting
      # include PostgreSQL::ReferentialIntegrity
      include Sunstone::SchemaStatements
      include Sunstone::DatabaseStatements
      include Sunstone::ColumnDumper
      # include Savepoints
      
      # Returns 'SunstoneAPI' as adapter name for identification purposes.
      def adapter_name
        ADAPTER_NAME
      end
      
      # Initializes and connects a SunstoneAPI adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger, config)

        @prepared_statements = false
        @visitor = Arel::Visitors::Sunstone.new
        @connection_parameters, @config = connection_parameters, config

        connect

        @type_map = Type::HashLookupTypeMap.new
        initialize_type_map(type_map)
      end

      # Is this connection alive and ready for queries?
      def active?
        @connection.ping
        true
      rescue Net::HTTPExceptions
        false
      end

      # TODO: this doesn't work yet
      # Close then reopen the connection.
      def reconnect!
        super
        @connection.reset
        # configure_connection
      end

      # TODO don't know about this yet
      def reset!
        # configure_connection
      end
      
      # Executes the delete statement and returns the number of rows affected.
      def delete(arel, name = nil, binds = [])
        r = exec_delete(to_sql(arel, binds), name, binds)
        r.rows.first.to_i
      end

      # TODO: deal with connection.close
      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
        @connection.close rescue nil
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end

      def use_insert_returning?
        true
      end

      def valid_type?(type)
        !native_database_types[type].nil?
      end

      def update_table_definition(table_name, base) #:nodoc:
        SunstoneAPI::Table.new(table_name, base)
      end

      def collector
        Arel::Collectors::Sunstone.new
      end

      def server_config
        JSON.parse(@connection.get("/configuration").body)
      end
      
      def lookup_cast_type_from_column(column) # :nodoc:
        if column.array
          Sunstone::Type::Array.new(type_map.lookup(column.sql_type))
        else
          type_map.lookup(column.sql_type)
        end
      end
      
      def transaction(requires_new: nil, isolation: nil, joinable: true)
        Thread.current[:sunstone_transaction_count] ||= 0
        Thread.current[:sunstone_request_sent] = nil if Thread.current[:sunstone_transaction_count] == 0
        Thread.current[:sunstone_transaction_count] += 1
        begin
          yield
        ensure
          Thread.current[:sunstone_transaction_count] -= 1
          if Thread.current[:sunstone_transaction_count] == 0
            Thread.current[:sunstone_transaction_count] = nil
            Thread.current[:sunstone_request_sent] = nil
          end
        end
      end
      
      def supports_json?
        true
      end

      # Executes an INSERT query and returns the new record's ID
      #
      # +id_value+ will be returned unless the value is nil, in
      # which case the database will attempt to calculate the last inserted
      # id and return that value.
      #
      # If the next id was calculated in advance (as in Oracle), it should be
      # passed in as +id_value+.
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        sql, binds, pk, sequence_name = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
        value = exec_insert(sql, name, binds, pk, sequence_name)
      end
      alias create insert
      
      # Should be the defuat insert, but rails escapes if for SQL so we'll just
      # catch the string "DEFATUL VALUES" in the visitor
      # def empty_insert_statement_value
      #   {}
      # end
      
      private

        def initialize_type_map(m) # :nodoc:
          m.register_type 'boolean',    Type::Boolean.new
          m.register_type 'string',     Type::String.new
          m.register_type 'integer',    Type::Integer.new
          m.register_type 'decimal',    Type::Decimal.new
          m.register_type 'datetime',   Sunstone::Type::DateTime.new
          m.register_type 'json',       Type::Internal::AbstractJson.new
          m.register_type 'ewkb',       Sunstone::Type::EWKB.new
          m.register_type 'uuid',       Sunstone::Type::Uuid.new
        end

        # Connects to a Sunstone API server and sets up the adapter depending on
        # the connected server's characteristics.
        def connect
          @connection = ::Sunstone::Connection.new(@connection_parameters)
        end

        def create_table_definition(name, temporary, options, as = nil) # :nodoc:
          SunstoneAPI::TableDefinition.new native_database_types, name, temporary, options, as
        end
        
        ActiveRecord::Type.add_modifier({ array: true }, Sunstone::Type::Array, adapter: :sunstone)
        # ActiveRecord::Type.add_modifier({ range: true }, OID::Range, adapter: :postgresql)
    end
  end
end
