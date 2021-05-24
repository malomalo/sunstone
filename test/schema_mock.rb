class ActiveSupport::TestCase
  class Schema

    class Table

      class Column

        def initialize(name, type, options={})
          @name = name
          @type = type
          @options = options
        end

        def as_json
          {type: @type, primary_key: false, null: true, array: false}.merge(@options)
        end
      end

      attr_accessor :name, :options, :columns

      def initialize(name, options={}, &block)
        @name = name
        @options = options
        @columns = {}
        case options[:id]
        when false
        else
          integer('id', primary_key: true, null: false)
        end

        block.call(self)
      end

      def string(name, options={})
        @columns[name] = Column.new(name, :string, options)
      end
      
      def text(name, options={})
        @columns[name] = Column.new(name, :text, options)
      end

      def datetime(name, options={})
        @columns[name] = Column.new(name, :datetime, options)
      end

      def integer(name, options={})
        @columns[name] = Column.new(name, :integer, options)
      end
      
      def json(name, options={})
        @columns[name] = Column.new(name, :json, options)
      end
      
      def to_json
        json = @options.slice(:limit)
        json[:columns] = {}
        @columns.each do |name, column|
          json[:columns][name] = column.as_json
        end
        json.to_json
      end

    end

    attr_accessor :tables

    def initialize
      @tables = {}
    end

    def self.define(&block)
      i = new
      i.define(&block)
      i
    end

    def define(&block)
      instance_eval(&block)
    end

    def create_table(name, options={}, &block)
      @tables[name] = Table.new(name, options, &block)
    end

  end

  def self.schema(&block)
    self.class_variable_set(:@@schema, Schema.define(&block))
  end

  set_callback(:setup, :before) do
    if !instance_variable_defined?(:@suite_setup_run) && self.class.class_variable_defined?(:@@schema)
      ActiveRecord::Base.establish_connection(adapter: 'sunstone', url: 'http://example.com')

      req_stub = stub_request(:get, /^http:\/\/example.com/).with do |req|
        case req.uri.path
        when '/tables'
          true
        when /^\/\w+\/schema$/i
          true
        else
          false
        end
      end

      req_stub.to_return do |req|
        case req.uri.path
        when '/tables'
          {
            body: self.class.class_variable_get(:@@schema).tables.keys.to_json,
            headers: { 'StandardAPI-Version' => '6.0.0.29' }
          }
        when /^\/(\w+)\/schema$/i
          {
            body: self.class.class_variable_get(:@@schema).tables[$1].to_json,
            headers: { 'StandardAPI-Version' => '6.0.0.29' }
          }
        end
      end

    end
    @suite_setup_run = true
  end

end
