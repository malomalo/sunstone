require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'

require 'arel/visitors/sunstone'
require 'arel/collectors/sunstone'

require 'active_record/connection_adapters/sunstone/database_statements'
require 'active_record/connection_adapters/sunstone/schema_statements'
require 'active_record/connection_adapters/sunstone/column'

require 'active_record/connection_adapters/sunstone/type/date_time'

module ActiveRecord
  module ConnectionHandling # :nodoc:

    VALID_SUNSTONE_CONN_PARAMS = [:site, :host, :port, :api_key, :use_ssl, :user_agent]

    # Establishes a connection to the database that's used by all Active Record
    # objects
    def sunstone_connection(config)
      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]
      if conn_params[:site]
        uri = URI.parse(conn_params.delete(:site))
        conn_params[:api_key] ||= (uri.user ? CGI.unescape(uri.user) : nil)
        conn_params[:host]    ||= uri.host
        conn_params[:port]    ||= uri.port
        conn_params[:use_ssl] ||= (uri.scheme == 'https')
      end
      
      # Forward only valid config params to PGconn.connect.
      conn_params.keep_if { |k, _| VALID_SUNSTONE_CONN_PARAMS.include?(k) }

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
      ADAPTER_NAME = 'Sunstone'

      NATIVE_DATABASE_TYPES = {
        string:      { name: "string" },
        number:      { name: "number" },
        json:        { name: "json" },
        boolean:     { name: "boolean" }
      }

      include Sunstone::DatabaseStatements
      include Sunstone::SchemaStatements
      
      # Returns 'SunstoneAPI' as adapter name for identification purposes.
      def adapter_name
        ADAPTER_NAME
      end
      
      # Adds `:array` option to the default set provided by the AbstractAdapter
      def prepare_column_options(column, types) # :nodoc:
        spec = super
        spec[:array] = 'true' if column.respond_to?(:array) && column.array
        spec
      end

      # Initializes and connects a SunstoneAPI adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger)

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
        Wankel.parse(@connection.get("/configuration").body)
      end

      private

        def initialize_type_map(m) # :nodoc:
          m.register_type 'boolean',    Type::Boolean.new
          m.register_type 'string',     Type::String.new
          m.register_type 'integer',    Type::Integer.new
          m.register_type 'decimal',    Type::Decimal.new
          m.register_type 'datetime',   Sunstone::Type::DateTime.new
          m.register_type 'hash',       Type::Value.new
        end

        def exec(arel, name='SAR', binds=[])
          # result = without_prepared_statement?(binds) ? exec_no_cache(sql, name, binds) :
          #                                               exec_cache(sql, name, binds)
          sar = to_sar(arel, binds)

          log(sar.is_a?(String) ? sar : "#{sar.class} #{CGI.unescape(sar.path)}", name) { Wankel.parse(@connection.send_request(sar).body) }
        end

        # Connects to a Sunstone API server and sets up the adapter depending on
        # the connected server's characteristics.
        def connect
          @connection = ::Sunstone::Connection.new(@connection_parameters)
        end

        def create_table_definition(name, temporary, options, as = nil) # :nodoc:
          SunstoneAPI::TableDefinition.new native_database_types, name, temporary, options, as
        end
    end
  end
end
