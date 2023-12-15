require 'active_record/connection_adapters/abstract_adapter'

require 'arel/nodes/relation'
require 'arel/visitors/to_sql_extensions'

require 'active_record/connection_adapters/sunstone/database_statements'
require 'active_record/connection_adapters/sunstone/schema_statements'
require 'active_record/connection_adapters/sunstone/schema_dumper'
require 'active_record/connection_adapters/sunstone/column'

require 'active_record/connection_adapters/sunstone/type/date_time'
require 'active_record/connection_adapters/sunstone/type/array'
require 'active_record/connection_adapters/sunstone/type/binary'
require 'active_record/connection_adapters/sunstone/type/uuid'
require 'active_record/connection_adapters/sunstone/type/json'

module ActiveRecord
  module ConnectionHandling # :nodoc:

    def sunstone_adapter_class
      ConnectionAdapters::SunstoneAPIAdapter
    end
    
    # Establishes a connection to the database that's used by all Active Record
    # objects
    def sunstone_connection(config)
      sunstone_adapter_class.new(config)
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
      VALID_SUNSTONE_CONN_PARAMS = [:url, :host, :port, :api_key, :use_ssl, :user_agent, :ca_cert]

      NATIVE_DATABASE_TYPES = {
        string:      { name: "string" },
        number:      { name: "number" },
        json:        { name: "json" },
        boolean:     { name: "boolean" }
      }
      
      class << self
        def new_client(conn_params)
          ::Sunstone::Connection.new(conn_params)
        end
      end

      # include PostgreSQL::Quoting
      # include PostgreSQL::ReferentialIntegrity
      include Sunstone::SchemaStatements
      include Sunstone::DatabaseStatements
      include Sunstone::ColumnDumper
      # include Savepoints

      def supports_statement_cache?
        false
      end
      
      def default_prepared_statements
        false
      end

      def clear_cache!(new_connection: false)
        # TODO move @definitions to using @schema_cache
        @definitions = {}
      end

      # Initializes and connects a SunstoneAPI adapter.
      def initialize(...)
        super

        conn_params = @config.compact
        if conn_params[:url]
          uri = URI.parse(conn_params.delete(:url))
          conn_params[:api_key] ||= (uri.user ? CGI.unescape(uri.user) : nil)
          conn_params[:host]    ||= uri.host
          conn_params[:port]    ||= uri.port
          conn_params[:use_ssl] ||= (uri.scheme == 'https')
        end

        # Forward only valid config params to Sunstone::Connection
        conn_params.slice!(*VALID_SUNSTONE_CONN_PARAMS)

        @connection_parameters = conn_params

        @max_identifier_length = nil
        @type_map = nil
        @raw_connection = nil
      end

      def url(path=nil)
        "http#{@connection_parameters[:use_ssl] ? 's' : ''}://#{@connection_parameters[:host]}#{@connection_parameters[:port] != 80 ? (@connection_parameters[:port] == 443 && @connection_parameters[:use_ssl] ? '' : ":#{@connection_parameters[:port]}") : ''}#{path}"
      end

      def active?
        @raw_connection&.active?
      end

      def load_type_map
        @type_map = Type::HashLookupTypeMap.new
        initialize_type_map(@type_map)
      end
      
      def reconnect
        super
        @raw_connection&.reconnect!
      end

      def disconnect!
        super
        @raw_connection&.disconnect!
        @raw_connection = nil
      end

      def discard! # :nodoc:
        super
        @raw_connection = nil
      end

      # Executes the delete statement and returns the number of rows affected.
      def delete(arel, name = nil, binds = [])
        r = exec_delete(arel, name, binds)
        r.rows.first.to_i
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

      def arel_visitor
        Arel::Visitors::Sunstone.new
      end

      def collector
        Arel::Collectors::Sunstone.new
      end

      def server_config
        with_raw_connection do |conn|
          JSON.parse(conn.get("/configuration").body)
        end
      end

      def return_value_after_insert?(column) # :nodoc:
        column.auto_populated?
      end

      def lookup_cast_type_from_column(column) # :nodoc:
        cast_type = @type_map.lookup(column.sql_type, {
          limit: column.limit,
          precision: column.precision,
          scale: column.scale
        })
        column.array ? Sunstone::Type::Array.new(cast_type) : cast_type
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
      rescue ActiveRecord::Rollback
        # rollbacks are silently swallowed
      end

      def supports_json?
        true
      end

      # Executes an INSERT query and returns a hash of the object and
      # any updated relations. This is different from AR which returns an ID
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [], returning: nil)
        exec_insert(arel, name, binds, pk, sequence_name, returning: returning)
      end
      alias create insert

      # Connects to a StandardAPI server and sets up the adapter depending
      # on the connected server's characteristics.
      def connect
        @raw_connection = self.class.new_client(@connection_parameters)
      end

      def reconnect
        @raw_connection&.reconnect!
        connect unless @raw_connection
      end

      # Configures the encoding, verbosity, schema search path, and time zone of the connection.
      # This is called by #connect and should not be called manually.
      def configure_connection
        reload_type_map
      end

      def reload_type_map
        if @type_map
          type_map.clear
        else
          @type_map = Type::HashLookupTypeMap.new
        end

        initialize_type_map
      end

      private
      
      def initialize_type_map(m = nil)
        self.class.initialize_type_map(m || @type_map)
      end

      def self.initialize_type_map(m) # :nodoc:
        m.register_type               'boolean',    Type::Boolean.new
        m.register_type               'binary'      do |_, options|
          Sunstone::Type::Binary.new(**options.slice(:limit))
        end
        m.register_type               'datetime',   Sunstone::Type::DateTime.new
        m.register_type               'decimal'     do |_, options|
          Type::Decimal.new(**options.slice(:precision, :scale))
        end
        m.register_type               'integer'     do |_, options|
          Type::Integer.new(**options.slice(:limit))
        end
        m.register_type               'json',       Sunstone::Type::Json.new
        m.register_type               'string'      do |_, options|
          Type::String.new(**options.slice(:limit))
        end
        m.register_type               'uuid',       Sunstone::Type::Uuid.new

        if defined?(Sunstone::Type::EWKB)
          m.register_type 'ewkb',       Sunstone::Type::EWKB.new
        end
      end

      def create_table_definition(name, **options)
        SunstoneAPI::TableDefinition.new(self, name, **options)
      end

      ActiveRecord::Type.add_modifier({ array: true }, Sunstone::Type::Array, adapter: :sunstone)
      # ActiveRecord::Type.add_modifier({ range: true }, OID::Range, adapter: :postgresql)
    end
  end
end
