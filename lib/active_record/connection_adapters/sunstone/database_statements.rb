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
            
            col = collector()
            col.retryable = true
            sar = visitor.compile(arel_or_sar_string, col)
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

        # Lowest level way to execute a query. Doesn't check for illegal writes, doesn't annotate queries, yields a native result object.
        def raw_execute(arel, name = nil, binds = [], prepare: false, async: false, allow_retry: false, materialize_transactions: true, batch: false)
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
          
          send_request = lambda { |conn, req_arel, batch|
            sar = to_sar(req_arel, type_casted_binds)
            log_mess = sar.path.split('?', 2)
            log("#{sar.method} #{log_mess[0]} #{(log_mess[1] && !log_mess[1].empty?) ? MessagePack.unpack(CGI.unescape(log_mess[1])) : '' }", name) do |notification_payload|
              result = perform_query(conn, sar, prepare:, notification_payload:, batch: batch)
              result.instance_variable_set(:@sunstone_calculation, true) if result && sar.instance_variable_get(:@sunstone_calculation)
              result
            end
          }
          
          result = with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
            if multiple_requests
              binds.delete_at(limit_bind_index) if limit_bind_index

              limit, offset, results = allowed_limit, 0, nil
              last_affected_rows = 0
              while requested_limit ? offset < requested_limit : true
                split_arel = arel.dup
                split_arel.limit = limit
                split_arel.offset = offset
                request_results = send_request.call(conn, split_arel, true)
                last_affected_rows += @last_affected_rows
                if results
                  results.push(*request_results)
                else
                  results = request_results
                end
                break if request_results.size < limit
                offset = offset + limit
              end
              @last_affected_rows = last_affected_rows
              results
            else
              send_request.call(conn, arel, true)
            end
          end

          result
        end

        def perform_query(raw_connection, sar, prepare:, notification_payload:, batch: false)
          response = raw_connection.send_request(sar)
          result = response.is_a?(Net::HTTPNoContent) ? nil : JSON.parse(response.body)

          verified!
          # handle_warnings(result)
          @last_affected_rows = response['Affected-Rows'] || result&.count || 0
          notification_payload[:row_count] = @last_affected_rows
          result
        end
        
        # Receive a native adapter result object and returns an ActiveRecord::Result object.
        def cast_result(raw_result)
          if raw_result.instance_variable_defined?(:@sunstone_calculation) && raw_result.instance_variable_get(:@sunstone_calculation)
            # this is a count, min, max.... yea i know..
            ActiveRecord::Result.new(['all'], [raw_result], {:all => @type_map.lookup('integer', {})})
          elsif raw_result.is_a?(Array)
            ActiveRecord::Result.new(raw_result[0] ? raw_result[0].keys : [], raw_result.map{|r| r.values})
          else
            ActiveRecord::Result.new(raw_result.keys, [raw_result.values])
          end
        end

        def affected_rows(raw_result)
          @last_affected_rows
        end
        
        def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [], returning: nil)
          sar, binds = to_sar_and_binds(arel, binds)
          value = exec_insert(sar, name, binds, pk, sequence_name, returning: returning)

          return returning_column_values(value) unless returning.nil?

          id_value || last_inserted_id(value)
        end
        alias create insert

        # Executes the update statement and returns the number of rows affected.
        def update(arel, name = nil, binds = [])
          sar, binds = to_sar_and_binds(arel, binds)
          internal_exec_query(sar, name, binds)
        end
        
        # Executes the delete statement and returns the number of rows affected.
        def delete(arel, name = nil, binds = [])
          sql, binds = to_sar_and_binds(arel, binds)
          exec_delete(sql, name, binds)
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

