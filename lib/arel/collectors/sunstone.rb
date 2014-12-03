module Arel
  module Collectors
    class Sunstone < Arel::Collectors::Bind

      attr_accessor :request_type, :table, :where, :limit, :offset, :order, :operation, :columns, :updates, :eager_loads, :id

      def substitute_binds hash, bvs
        if hash.is_a?(Array)
          hash.map { |w| substitute_binds(w, bvs) }
        else
          newhash = {}
          hash.each do |k, v|
            if Arel::Nodes::BindParam === v
              newhash[k] = (bvs.last.is_a?(Array) ? bvs.shift.last : bvs.shift)
            elsif v.is_a?(Hash)
              newhash[k] = substitute_binds(v, bvs)
            else
              newhash[k] = v
            end
          end
          newhash
        end
      end

      def value
        flatten_nested(where).flatten
      end

      def flatten_nested(obj)
        if obj.is_a?(Array)
          obj.map { |w| flatten_nested(w) }
        elsif obj.is_a?(Hash)
          obj.map{ |k,v| [k, flatten_nested(v)] }.flatten
        else
          obj
        end
      end

      def compile bvs, conn = nil
        path = "/#{table}"

        if updates
          body = {table.singularize => substitute_binds(updates.clone, bvs)}.to_json
        end

        get_params = {}
        if where
          get_params[:where] = substitute_binds(where.clone, bvs)
          if get_params[:where].size == 1
            get_params[:where] = get_params[:where].pop
          end
        end
        
        if eager_loads
          get_params[:include] = eager_loads.clone
        end

        get_params[:limit] = limit if limit
        get_params[:offset] = offset if offset
        get_params[:order] = order if order
        get_params[:columns] = columns if columns

        case operation
        when :count, :average, :min, :max
          path += "/#{operation}"
        when :update, :delete
          path += "/#{get_params[:where]['id']}"
          get_params.delete(:where)
        end
        
        if get_params.size > 0
          path += '?' + get_params.to_param
        end

        request = request_type.new(path)

        if updates
          request.body = body
        end

        request
      end

    end
  end
end



