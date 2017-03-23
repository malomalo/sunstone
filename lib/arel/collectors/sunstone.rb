module Arel
  module Collectors
    class Sunstone < Arel::Collectors::Bind

      MAX_URI_LENGTH = 2083

      attr_accessor :request_type, :table, :where, :limit, :offset, :order, :operation, :columns, :updates, :eager_loads, :id, :distinct, :distinct_on

      # This is used to removed an bind values. It is not used in the request
      attr_accessor :join_source
      
      def initialize
        @join_source = []
        super
      end

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
        elsif hash.is_a?(Arel::Nodes::BindParam)
          cast_attribute(bvs.last.is_a?(Array) ? bvs.shift.last : bvs.shift)
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
        headers = {}
        request_type_override = nil

        body = nil
        if updates
          body = {
            table.singularize => substitute_binds(updates.clone, bvs)
          }
        end

        if !join_source.empty?
          substitute_binds(join_source.clone, bvs)
        end

        params = {}
        if where
          params[:where] = substitute_binds(where.clone, bvs)
          if params[:where].size == 1
            params[:where] = params[:where].pop
          end
        end

        if eager_loads
          params[:include] = eager_loads.clone
        end

        if distinct_on
          params[:distinct_on] = distinct_on
        elsif distinct
          params[:distinct] = true 
        end

        if limit.is_a?(Arel::Nodes::BindParam)
          params[:limit] = substitute_binds(limit, bvs)
        elsif limit
          params[:limit] = limit
        end

        params[:order] = substitute_binds(order, bvs) if order

        if offset.is_a?(Arel::Nodes::BindParam)
          params[:offset] = substitute_binds(offset, bvs)
        elsif offset
          params[:offset] = offset
        end

        case operation
        when :count
          path += "/#{operation}"
        when :calculate
          path += "/calculate"
          params[:select] = columns
        when :update, :delete
          path += "/#{params[:where]['id']}"
          params.delete(:where)
        end
        
        if params.size > 0 && request_type == Net::HTTP::Get
          newpath = path + "?#{CGI.escape(MessagePack.pack(params))}"
          if newpath.length > MAX_URI_LENGTH
            request_type_override = Net::HTTP::Post
            headers['X-Http-Method-Override'] = 'GET'
            if body
              body.merge!(params)
            else
              body = params
            end
          else
            path = newpath
            headers['Query-Encoding'] = 'application/msgpack'
          end
        end

        request = (request_type_override || request_type).new(path)
        headers.each { |k,v| request[k] = v }
        request.instance_variable_set(:@sunstone_calculation, true) if [:calculate, :delete].include?(operation)

        if body
          request.body = body.to_json
        end

        request
      end

    end
  end
end
