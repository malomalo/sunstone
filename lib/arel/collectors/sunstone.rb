module Arel
  module Collectors
    class Sunstone < Arel::Collectors::Bind

      attr_accessor :request_type, :table, :where, :limit, :offset, :order, :operation, :columns, :updates, :eager_loads, :id

      def cast_attribute(v)
        if (v.is_a?(ActiveRecord::Attribute))
          v.value_for_database
        else
          v
        end
      end

      def substitute_binds hash, bvs
        if hash.is_a?(Array)
          hash.map do |v|
            if v.is_a?(Arel::Nodes::BindParam)
              cast_attribute(bvs.last.is_a?(Array) ? bvs.shift.last : bvs.shift)
            elsif v.is_a?(Hash) || v.is_a?(Array)
              substitute_binds(v, bvs)
            else
              v
            end
          end
        elsif hash.is_a?(Hash)
          newhash = {}
          hash.each do |k, v|
            if v.is_a?(Arel::Nodes::BindParam)
              newhash[k] = cast_attribute(bvs.last.is_a?(Array) ? bvs.shift.last : bvs.shift)
            elsif v.is_a?(Hash)
              newhash[k] = substitute_binds(v, bvs)
            elsif v.is_a?(Array)
              newhash[k] = substitute_binds(v, bvs)
            else
              newhash[k] = v
            end
          end
          newhash
        else
          cast_attribute(bvs.last.is_a?(Array) ? bvs.shift.last : bvs.shift)
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


        if limit.is_a?(Arel::Nodes::BindParam)
          get_params[:limit] = substitute_binds(limit, bvs)
        elsif limit
          get_params[:limit] = limit
        end

        if offset.is_a?(Arel::Nodes::BindParam)
          get_params[:offset] = substitute_binds(offset, bvs)
        elsif offset
          get_params[:offset] = offset
        end

        get_params[:order] = substitute_binds(order, bvs) if order

        case operation
        when :count
          path += "/#{operation}"
        when :calculate
          path += "/calculate"
          get_params[:select] = columns
        when :update, :delete
          path += "/#{get_params[:where]['id']}"
          get_params.delete(:where)
        end
        if get_params.size > 0
          path += "?#{CGI.escape(MessagePack.pack(get_params))}"
        end
        
        request = request_type.new(path)
        if get_params.size > 0
          request['Query-Encoding'] = 'application/msgpack'
        end
        request.instance_variable_set(:@sunstone_calculation, true) if [:calculate, :delete].include?(operation)

        if updates
          request.body = body
        end

        request
      end

    end
  end
end



