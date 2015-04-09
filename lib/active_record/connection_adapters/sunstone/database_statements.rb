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

        # Returns an ActiveRecord::Result instance.
        def select_all(arel, name = nil, binds = [], &block)
          exec_query(arel, name, binds)
        end

        def exec_query(arel, name = 'SAR', binds = [])
          sar = to_sar(arel, binds)
          result = exec(sar, name)

          if sar.instance_variable_get(:@sunstone_calculation)
            # this is a count, min, max.... yea i know..
            ActiveRecord::Result.new(['all'], [result], {:all => type_map.lookup('integer')})
          else
            ActiveRecord::Result.new(result[0] ? result[0].keys : [], result.map{|r| r.values})
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





