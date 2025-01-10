require "arel/collectors/sql_string"

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module DatabaseStatements

        def to_sql(arel, binds = [])
          if arel.respond_to?(:ast)
            unless binds.empty?
              raise "Passing bind parameters with an arel AST is forbidden. " \
                "The values must be stored on the AST directly"
            end
            Arel::Visitors::ToSql.new(self).accept(arel.ast, Arel::Collectors::SubstituteBinds.new(self, Arel::Collectors::SQLString.new)).value
          else
            arel.dup.freeze
          end
        end
        
        # Converts an arel AST to a Sunstone API Request
        def to_sar(arel_or_sar_string, binds = nil)
          if arel_or_sar_string.respond_to?(:ast)
            sar = visitor.accept(arel_or_sar_string.ast, collector)
            binds = sar.binds if binds.nil?
          else
            sar = arel_or_sar_string
          end

          sar.compile(binds)
        end
        
        def to_sar_and_binds(arel_or_sar_string, binds = [], preparable = nil, allow_retry = false)
          # Arel::TreeManager -> Arel::Node
          if arel_or_sar_string.respond_to?(:ast)
            arel_or_sar_string = arel_or_sar_string.ast
          end

          if Arel.arel_node?(arel_or_sar_string) && !(String === arel_or_sar_string)
            unless binds.empty?
              raise "Passing bind parameters with an arel AST is forbidden. " \
                "The values must be stored on the AST directly"
            end
            
            c = collector()
            c.retryable = true
            sar = visitor.compile(arel_or_sar_string, c)
            puts sar.inspect
            [sar.freeze, sar.binds, false, allow_retry]
          else
            arel_or_sar_string = arel_or_sar_string.dup.freeze unless arel_or_sar_string.frozen?
            [arel_or_sar_string, binds, false, allow_retry]
          end
        end
        
        def sar_for_insert(sql, pk, binds, returning)
          # TODO: when StandardAPI supports returning we can do this; it might
          # already need to investigate
          to_sar_and_binds(sql, binds)
        end
        
        # This is used in the StatementCache object. It returns an object that
        # can be used to query the database repeatedly.
        def cacheable_query(klass, arel) # :nodoc:
          if prepared_statements
            sql, binds = visitor.compile(arel.ast, collector)
            query = klass.query(sql)
          elsif self.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
            collector = SunstonePartialQueryCollector.new(self.collector)
            parts, binds = visitor.compile(arel.ast, collector)
            query = StatementCache::PartialQuery.new(parts, true)
          else
            collector = klass.partial_query_collector
            parts, binds = visitor.compile(arel.ast, collector)
            query = klass.partial_query(parts)
          end
          [query, binds]
        end

        class SunstonePartialQueryCollector
          delegate_missing_to :@collector
          
          def initialize(collector)
            @collector = collector
            @binds = []
          end

          def add_bind(obj)
            @binds << obj
          end

          def value
            [@collector, @binds]
          end
        end

        # Returns an ActiveRecord::Result instance.
        def select_all(arel, name = nil, binds = [], preparable: nil, async: false, allow_retry: false)
          arel = arel_from_relation(arel)
          sar, binds, preparable, allow_retry = to_sar_and_binds(arel, binds, preparable, allow_retry)

          select(sar, name, binds,
            prepare: prepared_statements && preparable,
            async: async && FutureResult::SelectAll,
            allow_retry: allow_retry
          )
        rescue ::RangeError
          ActiveRecord::Result.empty(async: async)
        end
        
        # Executes insert +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        # Some adapters support the `returning` keyword argument which allows to control the result of the query:
        # `nil` is the default value and maintains default behavior. If an array of column names is passed -
        # the result will contain values of the specified columns from the inserted row.
        #
        # TODO: Add support for returning
        def exec_insert(arel, name = nil, binds = [], pk = nil, sequence_name = nil, returning: nil)
          sar, binds = sar_for_insert(arel, pk, binds, returning)
          internal_exec_query(sar, name, binds)
        end

        def internal_exec_query(arel, name = 'SAR', binds = [], prepare: false, async: false, allow_retry: false)
          sars = []
          multiple_requests = arel.is_a?(Arel::Collectors::Sunstone)
          type_casted_binds = binds#type_casted_binds(binds)
          
          if multiple_requests
            allowed_limit = limit_definition(arel.table)
            limit_bind_index = nil#binds.find_index { |x| x.name == 'LIMIT' }
            requested_limit = if limit_bind_index
              type_casted_binds[limit_bind_index]
            else
              arel.limit
            end

            if allowed_limit.nil?
              multiple_requests = false
            elsif requested_limit && requested_limit <= allowed_limit
              multiple_requests = false
            else
              multiple_requests = true
            end
          end

          send_request = lambda { |req_arel|
            sar = to_sar(req_arel, type_casted_binds)
            sars.push(sar)
            log_mess = sar.path.split('?', 2)
            log("#{sar.method} #{log_mess[0]} #{(log_mess[1] && !log_mess[1].empty?) ? MessagePack.unpack(CGI.unescape(log_mess[1])) : '' }", name) do
              with_raw_connection do |conn|
                response = conn.send_request(sar)
                if response.is_a?(Net::HTTPNoContent)
                  nil
                else
                  JSON.parse(response.body)
                end
              end
            end
          }

          result = if multiple_requests
            binds.delete_at(limit_bind_index) if limit_bind_index

            limit, offset, results = allowed_limit, 0, []
            while requested_limit ? offset < requested_limit : true
              split_arel = arel.dup
              split_arel.limit = limit
              split_arel.offset = offset
              request_results = send_request.call(split_arel)
              results = results + request_results
              break if request_results.size < limit
              offset = offset + limit
            end
            results
          else
            send_request.call(arel)
          end
          
          if sars[0].instance_variable_defined?(:@sunstone_calculation) && sars[0].instance_variable_get(:@sunstone_calculation)
            # this is a count, min, max.... yea i know..
            ActiveRecord::Result.new(['all'], [result], {:all => @type_map.lookup('integer', {})})
          elsif result.is_a?(Array)
            ActiveRecord::Result.new(result[0] ? result[0].keys : [], result.map{|r| r.values})
          else
            ActiveRecord::Result.new(result.keys, [result.values])
          end
        end
        
        def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [], returning: nil)
          sar, binds = to_sar_and_binds(arel, binds)
          value = exec_insert(sar, name, binds, pk, sequence_name, returning: returning)

          return returning_column_values(value) unless returning.nil?

          id_value || last_inserted_id(value)
        end
        
        def update(...)
          exec_update(...)
        end
        
        def delete(arel, name = nil, binds = [])
          exec_delete(arel, name, binds)
        end

        def last_inserted_id(result)
          row = result.rows.first
          row && row['id']
        end

        def returning_column_values(result)
          result.rows.first
        end

      end
    end
  end
end

