module Arel
  module Collectors
    class Sunstone < Arel::Collectors::Bind
      
      attr_accessor :request_type, :table, :where, :limit, :offset, :order, :operation
      
      def substitute_binds hash, bvs
        if hash.is_a?(Array)
          hash.map { |w| substitute_binds(w, bvs) }
        else
          newhash = {}
          hash.each do |k, v|
            if Arel::Nodes::BindParam === v
              newhash[k] = bvs.shift.last
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
      
      def compile bvs
        path = "/#{table}"
        
        case operation
        when :count
          path += '/count'
        end
        
        get_params = {}
        
        if where
          get_params[:where] = substitute_binds(where, bvs)
          if get_params[:where].size == 1
            get_params[:where] = get_params[:where].pop
          end
        end
        
        get_params[:limit] = limit if limit
        get_params[:offset] = offset if offset
        get_params[:order] = order if order
        
        if get_params.size > 0
          path += '?' + get_params.to_param
        end
          
        request = request_type.new(path)
        
        request
      end
      
    end
  end
end



