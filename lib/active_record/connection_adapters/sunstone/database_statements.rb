module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module DatabaseStatements

        # Converts an arel AST to a Sunstone API Request
        def to_sar(arel, bvs = [])
          if arel.respond_to?(:ast)
            collected = visitor.accept(arel.ast, collector)
            collected.compile(bvs, self)
          else
            arel
          end
        end

        def exec_query(arel, name = 'SAR', binds = [], prepare: false)
          sar = to_sar(arel, binds)
          
          log_mess = sar.path.split('?', 2)
          result = log("#{sar.method} #{log_mess[0]} #{(log_mess[1] && !log_mess[1].empty?) ? MessagePack.unpack(CGI.unescape(log_mess[1])) : '' }", name) {
            response = @connection.send_request(sar)
            if response.is_a?(Net::HTTPNoContent)
              nil
            else
              JSON.parse(response.body)
            end
          }

          if sar.instance_variable_get(:@sunstone_calculation)
            # this is a count, min, max.... yea i know..
            ActiveRecord::Result.new(['all'], [result], {:all => type_map.lookup('integer')})
          elsif result.is_a?(Array)
            ActiveRecord::Result.new(result[0] ? result[0].keys : [], result.map{|r| r.values})
          else
            ActiveRecord::Result.new(result.keys, [result])
          end
        end
        
        def last_inserted_id(result)
          row = result.rows.first
          row && row['id']
        end

      end
    end
  end
end





