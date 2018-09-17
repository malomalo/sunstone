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
        
        def to_sar_and_binds(arel_or_sar_string, binds = []) # :nodoc:
          if arel_or_sar_string.respond_to?(:ast)
            unless binds.empty?
              raise "Passing bind parameters with an arel AST is forbidden. " \
                "The values must be stored on the AST directly"
            end
            sar = visitor.accept(arel_or_sar_string.ast, collector)
            # puts ['a', sar.freeze, sar.binds].map(&:inspect)
            [sar.freeze, sar.binds]
          else
            # puts ['b',arel_or_sar_string.dup.freeze, binds].map(&:inspect)
            [arel_or_sar_string.dup.freeze, binds]
          end
        end
        
        # This is used in the StatementCache object. It returns an object that
        # can be used to query the database repeatedly.
        def cacheable_query(klass, arel) # :nodoc:
          if prepared_statements
            sql, binds = visitor.accept(arel.ast, collector).value
            query = klass.query(sql)
          elsif self.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
            collector = SunstonePartialQueryCollector.new(self.collector)
            parts, binds = visitor.accept(arel.ast, collector).value
            query = StatementCache::PartialQuery.new(parts, true)
          else
            collector = PartialQueryCollector.new
            parts, binds = visitor.accept(arel.ast, collector).value
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
        def select_all(arel, name = nil, binds = [], preparable: nil)
          arel = arel_from_relation(arel)
          sar, binds = to_sar_and_binds(arel, binds)
          select(sar, name, binds)
        end

        def exec_query(arel, name = 'SAR', binds = [], prepare: false)
          sars = []
          multiple_requests = arel.is_a?(Arel::Collectors::Sunstone)
          type_casted_binds = binds#type_casted_binds(binds)
          
          if multiple_requests
            allowed_limit = limit_definition(arel.table)
            limit_bind_index = nil#binds.find_index { |x| x.name == 'LIMIT' }
            requested_limit = if limit_bind_index
              type_casted_binds[limit_bind_index]
            else
              arel.limit&.value&.value_for_database
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
              response = @connection.send_request(sar)
              if response.is_a?(Net::HTTPNoContent)
                nil
              else
                JSON.parse(response.body)
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
            ActiveRecord::Result.new(['all'], [result], {:all => type_map.lookup('integer')})
          elsif result.is_a?(Array)
            ActiveRecord::Result.new(result[0] ? result[0].keys : [], result.map{|r| r.values})
          else
            ActiveRecord::Result.new(result.keys, [result])
          end
        end
        
        def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
          sar, binds = to_sar_and_binds(arel, binds)
          value = exec_insert(sar, name, binds, pk, sequence_name)
          id_value || last_inserted_id(value)
          
          # value = exec_insert(arel, name, binds, pk, sequence_name)
          # id_value || last_inserted_id(value)
        end
        
        def update(arel, name = nil, binds = [])
          exec_update(arel, name, binds)
        end
        
        def delete(arel, name = nil, binds = [])
          exec_delete(arel, name, binds)
        end

        def last_inserted_id(result)
          row = result.rows.first
          row && row['id']
        end

      end
    end
  end
end

