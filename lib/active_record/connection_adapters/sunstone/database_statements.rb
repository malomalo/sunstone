require "arel/collectors/sql_string"

module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module DatabaseStatements

        def to_sql(arel, binds = [])
          if arel.respond_to?(:ast)
            collected = Arel::Visitors::ToSql.new(self).accept(arel.ast, prepared_statements ? AbstractAdapter::SQLString.new : AbstractAdapter::BindCollector.new)
            collected.compile(binds, self).freeze
          else
            arel.dup.freeze
          end
        end
        
        # Converts an arel AST to a Sunstone API Request
        def to_sar(arel, bvs = [])
          if arel.respond_to?(:ast)
            collected = visitor.accept(arel.ast, collector)
            collected.compile(bvs, self)
          else
            arel
          end
        end
        
        def cacheable_query(klass, arel) # :nodoc:
          collected = visitor.accept(arel.ast, collector)
          if prepared_statements
            klass.query(collected.value)
          else
            if self.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
              StatementCache::PartialQuery.new(collected, true)
            else
              StatementCache::PartialQuery.new(collected.value, false)
            end
          end
        end

        # Returns an ActiveRecord::Result instance.
        def select_all(arel, name = nil, binds = [], preparable: nil)
          arel, binds = binds_from_relation arel, binds
          select(arel, name, binds)
        end

        def exec_query(arel, name = 'SAR', binds = [], prepare: false)
          sars = []
          multiple_requests = arel.is_a?(Arel::SelectManager)

          if multiple_requests
            allowed_limit = limit_definition(arel.source.left.name)
            requested_limit = binds.find { |x| x.name == 'LIMIT' }&.value

            if allowed_limit.nil?
              multiple_requests = false
            elsif requested_limit && requested_limit <= allowed_limit
              multiple_requests = false
            else
              multiple_requests = true
            end
          end

          send_request = lambda { |req_arel|
            sar = to_sar(req_arel, binds)
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
            bind = binds.find { |x| x.name == 'LIMIT' }
            binds.delete(bind)

            limit, offset, results = allowed_limit, 0, []
            while requested_limit ? offset < requested_limit : true
              split_arel = arel.clone
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
          value = exec_insert(arel, name, binds, pk, sequence_name)
          id_value || last_inserted_id(value)
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

