module ActiveRecord
  module ConnectionAdapters
    module Sunstone
      module DatabaseStatements
        
        # Converts an arel AST to a Sunstone API Request
        def to_sar(arel, bvs)
          if arel.respond_to?(:ast)
            collected = visitor.accept(arel.ast, collector)
            collected.compile(bvs)
          else
            arel
          end
        end
              
        # Returns an ActiveRecord::Result instance.
        def select_all(arel, name = nil, binds = [], &block)
          exec_query(arel, name, binds)
        end
        
        def exec_query(arel, name = 'SAR', binds = [])
          result = exec(to_sar(arel, binds), name)

          if result.is_a?(Array)
            ActiveRecord::Result.new(result[0] ? result[0].keys : [], result.map{|r| r.values})
          else
            # this is a count.. yea i know..
            ActiveRecord::Result.new(['all'], [[result]], {:all => type_map.lookup('integer')})
          end
        end

      end
    end
  end
end





