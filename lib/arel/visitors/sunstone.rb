require 'arel/visitors/visitor'
class Arel::Visitors::Dot
  def visit_Arel_Nodes_Casted o
    # collector << quoted(o.val, o.attribute).to_s
    visit_String o.val
  end
end

module Arel
  module Visitors
    class Sunstone < Arel::Visitors::Reduce
      
      def initialize
        @dispatch = get_dispatch_cache
      end
      
      def compile node, &block
        accept(node, Arel::Collectors::SQLString.new, &block).value
      end

      def preparable
        false
      end
      
      private
      
      def visit_Arel_Nodes_SelectStatement o, collector
        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore(x, c)
        }

        if !o.orders.empty?
          collector.order = o.orders.map { |x| visit(x, collector) }
        end
        
        collector = maybe_visit o.limit, collector
        collector = maybe_visit o.offset, collector
        collector = maybe_visit o.eager_load, collector
        # collector = maybe_visit o.lock, collector

        collector
      end

      def visit_Arel_Nodes_EagerLoad o, collector
        collector.eager_loads = o.expr
        collector
      end

      def visit_Arel_Nodes_SelectCore o, collector
        collector.request_type = Net::HTTP::Get

        unless o.projections.empty?
          o.projections.each { |proj| visit(proj, collector) }
        else
          collector.operation = :select
        end

        collector = maybe_visit o.set_quantifier, collector

        if o.source && !o.source.empty?
          collector = visit o.source, collector
        end

        if !o.wheres.empty?
          collector.where = o.wheres.map { |x| visit(x, collector) }.inject([]) { |c, w|
            w.is_a?(Array) ? c += w : c << w
          }
        end

        collector
      end
      
      def visit_Arel_Nodes_Overlaps o, collector
        { visit(o.left, collector) => {overlaps: o.left.type_cast_for_database(o.right) }}
      end
      
      def visit_Arel_Nodes_InsertStatement o, collector
        collector.request_type  = Net::HTTP::Post
        collector.table         = o.relation.name
        collector.operation     = :insert
        
        if o.values
          
          if o.values.is_a?(Arel::Nodes::SqlLiteral) && o.values == 'DEFAULT VALUES'
            collector.updates = {}
          else
            keys = o.values.right.map { |x| visit(x, collector) }
            values = o.values.left
            collector.updates = {}
          

            keys.each_with_index do |k, i|
              if k.is_a?(Hash)
                add_to_bottom_of_hash_or_array(k, values[i])
                collector.updates.deep_merge!(k) { |key, v1, v2|
                  if (v1.is_a?(Array) && v2.is_a?(Array))
                    v2.each_with_index do |v, j|
                      if v1[j].nil?
                        v1[j] = v2[j]
                      else
                        v1[j].deep_merge!(v2[j]) unless v2[j].nil?
                      end
                    end
                    v1
                  else
                    v2
                  end
                }
              else
                collector.updates[k] = values[i]
              end
            end
          end
        end
        
        collector
      end
      
      def find_bottom(hash)
        if hash.is_a?(Hash)
          if hash.values.first.is_a?(Array) || hash.values.first.is_a?(Hash)
            find_bottom(hash.values.first)
          else
            hash
          end
        elsif hash.is_a?(Array)
          fnn = hash.find { |i| !i.nil? }
          if fnn.is_a?(Array) || fnn.is_a?(Hash)
            fnn
          else
            hash
          end
        end
      end
      
      def add_to_bottom_of_hash_or_array(hash, value)
        hash = find_bottom(hash)
        if hash.is_a?(Hash)
          nkey = hash.keys.first
          nvalue = hash.values.first
          hash[nkey] = { nvalue => value }
        elsif hash.is_a?(Array)
          fnni = hash.find_index { |i| !i.nil? }
          nvalue = hash[fnni]
          hash[fnni] = { nvalue => value }
        end
      end


      private

      def visit_Arel_Nodes_DeleteStatement o, collector
        collector.request_type  = Net::HTTP::Delete
        collector.table         = o.relation.name
        collector.operation     = :delete

        wheres = o.wheres.map { |x| visit(x, collector) }.inject([]) { |c, w|
          w.is_a?(Array) ? c += w : c << w
        }
        if wheres.size != 1 && wheres.first.size != 1 && !wheres['id']
          raise 'Upsupported'
        else
          collector.where = wheres
        end

        collector
      end
      #
      # # FIXME: we should probably have a 2-pass visitor for this
      # def build_subselect key, o
      #   stmt             = Nodes::SelectStatement.new
      #   core             = stmt.cores.first
      #   core.froms       = o.relation
      #   core.wheres      = o.wheres
      #   core.projections = [key]
      #   stmt.limit       = o.limit
      #   stmt.orders      = o.orders
      #   stmt
      # end
      #
      def visit_Arel_Nodes_UpdateStatement o, collector
        collector.request_type  = Net::HTTP::Patch
        collector.table         = o.relation.name
        collector.operation     = :update
        
        # collector.id = o.wheres.first.children.first.right
        if !o.wheres.empty?
          collector.where = o.wheres.map { |x| visit(x, collector) }.inject([]) { |c, w|
            w.is_a?(Array) ? c += w : c << w
          }
        end
        
        if collector.where.size != 1 && collector.where.first.size != 1 && !collector.where.first['id']
          raise 'Upsupported'
        end
        if !collector.where.first['id']
          collector.table = collector.where.first.keys.first if collector.is_a?(Arel::Collectors::Sunstone)
          collector.where[0] = {'id' => collector.where.first.values.first.values.first}
        end
        
        if o.values
          collector.updates = {}
          
          o.values.map { |x| visit(x, collector) }.each do |value|
            value.each do |key, v|
              if key.is_a?(Hash)
                add_to_bottom_of_hash_or_array(key, v)
                collector.updates.deep_merge!(key) { |k, v1, v2|
                  if (v1.is_a?(Array) && v2.is_a?(Array))
                    v2.each_with_index do |v2k, i|
                      if v1[i].nil?
                        v1[i] = v2[i]
                      else
                        v1[i].deep_merge!(v2[i]) unless v2[i].nil?
                      end
                    end
                    v1
                  else
                    v2
                  end
                }
              else
                collector.updates[key] = v
              end
            end
          end
        end
        
        collector
      end
      #
      #
      # def visit_Arel_Nodes_Exists o, collector
      #   collector << "EXISTS ("
      #   collector = visit(o.expressions, collector) << ")"
      #   if o.alias
      #     collector << " AS "
      #     visit o.alias, collector
      #   else
      #     collector
      #   end
      # end
      #
      def visit_Arel_Nodes_Casted o, collector
        # collector << quoted(o.val, o.attribute).to_s
        o.val
      end

      def visit_Arel_Nodes_Quoted o, collector
        o.expr
      end
      #
      # def visit_Arel_Nodes_True o, collector
      #   collector << "TRUE"
      # end
      #
      # def visit_Arel_Nodes_False o, collector
      #   collector << "FALSE"
      # end
      #
      # def table_exists? name
      #   @schema_cache.table_exists? name
      # end
      #
      # def column_for attr
      #   return unless attr
      #   name    = attr.name.to_s
      #   table   = attr.relation.table_name
      #
      #   return nil unless table_exists? table
      #
      #   column_cache(table)[name]
      # end
      #
      # def column_cache(table)
      #   @schema_cache.columns_hash(table)
      # end
      #
      # def visit_Arel_Nodes_Values o, collector
      #
      #   len = o.expressions.length - 1
      #   o.expressions.zip(o.columns).each_with_index { |(value, attr), i|
      #     if Nodes::SqlLiteral === value
      #       collector = visit value, collector
      #     else
      #       collector << quote(value, attr && column_for(attr)).to_s
      #     end
      #     unless i == len
      #       collector << ', '
      #     end
      #   }
      #
      # end
      #
      #
      #
      # def visit_Arel_Nodes_Bin o, collector
      #   visit o.expr, collector
      # end
      #
      def visit_Arel_Nodes_Distinct o, collector
        collector.distinct = true
        collector
      end

      def visit_Arel_Nodes_DistinctOn o, collector
        collector.distinct_on = o.expr.map(&:name)
        collector
      end
      #
      # def visit_Arel_Nodes_With o, collector
      #   collector << "WITH "
      #   inject_join o.children, collector, ', '
      # end
      #
      # def visit_Arel_Nodes_WithRecursive o, collector
      #   collector << "WITH RECURSIVE "
      #   inject_join o.children, collector, ', '
      # end
      #
      # def visit_Arel_Nodes_Union o, collector
      #   collector << "( "
      #   infix_value(o, collector, " UNION ") << " )"
      # end
      #
      # def visit_Arel_Nodes_UnionAll o, collector
      #   collector << "( "
      #   infix_value(o, collector, " UNION ALL ") << " )"
      # end
      #
      # def visit_Arel_Nodes_Intersect o, collector
      #   collector << "( "
      #   infix_value(o, collector, " INTERSECT ") << " )"
      # end
      #
      # def visit_Arel_Nodes_Except o, collector
      #   collector << "( "
      #   infix_value(o, collector, " EXCEPT ") << " )"
      # end
      #
      # def visit_Arel_Nodes_NamedWindow o, collector
      #   collector << quote_column_name(o.name)
      #   collector << " AS "
      #   visit_Arel_Nodes_Window o, collector
      # end
      #
      # def visit_Arel_Nodes_Window o, collector
      #   collector << "("
      #
      #   if o.partitions.any?
      #     collector << "PARTITION BY "
      #     collector = inject_join o.partitions, collector, ", "
      #   end
      #
      #   if o.orders.any?
      #     collector << ' ' if o.partitions.any?
      #     collector << "ORDER BY "
      #     collector = inject_join o.orders, collector, ", "
      #   end
      #
      #   if o.framing
      #     collector << ' ' if o.partitions.any? or o.orders.any?
      #     collector = visit o.framing, collector
      #   end
      #
      #   collector << ")"
      # end
      #
      # def visit_Arel_Nodes_Rows o, collector
      #   if o.expr
      #     collector << "ROWS "
      #     visit o.expr, collector
      #   else
      #     collector << "ROWS"
      #   end
      # end
      #
      # def visit_Arel_Nodes_Range o, collector
      #   if o.expr
      #     collector << "RANGE "
      #     visit o.expr, collector
      #   else
      #     collector << "RANGE"
      #   end
      # end
      #
      # def visit_Arel_Nodes_Preceding o, collector
      #   collector = if o.expr
      #                 visit o.expr, collector
      #               else
      #                 collector << "UNBOUNDED"
      #               end
      #
      #   collector << " PRECEDING"
      # end
      #
      # def visit_Arel_Nodes_Following o, collector
      #   collector = if o.expr
      #                 visit o.expr, collector
      #               else
      #                 collector << "UNBOUNDED"
      #               end
      #
      #   collector << " FOLLOWING"
      # end
      #
      # def visit_Arel_Nodes_CurrentRow o, collector
      #   collector << "CURRENT ROW"
      # end
      #
      # def visit_Arel_Nodes_Over o, collector
      #   case o.right
      #   when nil
      #     visit(o.left, collector) << " OVER ()"
      #   when Arel::Nodes::SqlLiteral
      #     infix_value o, collector, " OVER "
      #   when String, Symbol
      #     visit(o.left, collector) << " OVER #{quote_column_name o.right.to_s}"
      #   else
      #     infix_value o, collector, " OVER "
      #   end
      # end
      #
      # def visit_Arel_Nodes_Having o, collector
      #   collector << "HAVING "
      #   visit o.expr, collector
      # end
      #
      def visit_Arel_Nodes_Offset o, collector
        collector.offset = visit(o.expr, collector)
        collector
      end

      def visit_Arel_Nodes_Limit o, collector
        collector.limit = visit(o.expr, collector)
        collector
      end

      # FIXME: this does nothing on most databases, but does on MSSQL
      def visit_Arel_Nodes_Top o, collector
        collector
      end
      #
      # def visit_Arel_Nodes_Lock o, collector
      #   visit o.expr, collector
      # end
      #
      def visit_Arel_Nodes_Grouping o, collector
        visit(o.expr, collector)
      end
      #
      # def visit_Arel_SelectManager o, collector
      #   collector << "(#{o.to_sql.rstrip})"
      # end
      #
      def visit_Arel_Nodes_Ascending o, collector
        { visit(o.expr, collector) => :asc }
      end

      def visit_Arel_Nodes_Descending o, collector
        { visit(o.expr, collector) => :desc }
      end
      #
      # def visit_Arel_Nodes_Group o, collector
      #   visit o.expr, collector
      # end
      #
      # def visit_Arel_Nodes_NamedFunction o, collector
      #   collector << o.name
      #   collector << "("
      #   collector << "DISTINCT " if o.distinct
      #   collector = inject_join(o.expressions, collector, ", ") << ")"
      #   if o.alias
      #     collector << " AS "
      #     visit o.alias, collector
      #   else
      #     collector
      #   end
      # end
      #
      # def visit_Arel_Nodes_Extract o, collector
      #   collector << "EXTRACT(#{o.field.to_s.upcase} FROM "
      #   collector = visit o.expr, collector
      #   collector << ")"
      #   if o.alias
      #     collector << " AS "
      #     visit o.alias, collector
      #   else
      #     collector
      #   end
      # end
      #
      def visit_Arel_Nodes_Count o, collector
        collector.operation = :calculate
        
        collector.columns   ||= []
        collector.columns   << {:count => (o.expressions.first.is_a?(Arel::Attributes::Attribute) ? o.expressions.first.name : o.expressions.first) }
        # collector.columns   = visit o.expressions.first, collector
      end

      def visit_Arel_Nodes_Sum o, collector
        collector.operation = :calculate
        
        collector.columns   ||= []
        collector.columns   << {:sum => (o.expressions.first.is_a?(Arel::Attributes::Attribute) ? o.expressions.first.name : o.expressions.first) }
        # collector.columns   = visit o.expressions.first, collector
      end

      def visit_Arel_Nodes_Max o, collector
        collector.operation = :calculate
        
        collector.columns   ||= []
        if o.expressions.first.is_a?(Arel::Attributes::Attribute)
          relation = o.expressions.first.relation
          join_name = relation.table_alias || relation.name
          collector.columns << {:maximum => join_name ? o.expressions.first.name : "#{join_name}.#{o.expressions.first.name}"}
        else
          collector.columns << {:maximum => o.expressions.first}
        end
      end

      def visit_Arel_Nodes_Min o, collector
        collector.operation = :calculate

        collector.columns   ||= []
        if o.expressions.first.is_a?(Arel::Attributes::Attribute)
          relation = o.expressions.first.relation
          join_name = relation.table_alias || relation.name
          collector.columns << {:minimum => join_name ? o.expressions.first.name : "#{join_name}.#{o.expressions.first.name}"}
        else
          collector.columns << {:minimum => o.expressions.first}
        end
      end

      def visit_Arel_Nodes_Avg o, collector
        collector.operation = :calculate

        collector.columns   ||= []
        if o.expressions.first.is_a?(Arel::Attributes::Attribute)
          relation = o.expressions.first.relation
          join_name = relation.table_alias || relation.name
          collector.columns << {:average => join_name ? o.expressions.first.name : "#{join_name}.#{o.expressions.first.name}"}
        else

          collector.columns << {:average => o.expressions.first}
        end
      end
      #
      # def visit_Arel_Nodes_TableAlias o, collector
      #   collector = visit o.relation, collector
      #   collector << " "
      #   collector << quote_table_name(o.name)
      # end
      #
      # def visit_Arel_Nodes_Between o, collector
      #   collector = visit o.left, collector
      #   collector << " BETWEEN "
      #   visit o.right, collector
      # end

      def visit_Arel_Nodes_GreaterThanOrEqual o, collector
        key = visit(o.left, collector)
        value = { :gte => visit(o.right, collector) }
        if key.is_a?(Hash)
          if o.left.is_a?(Arel::Attributes::Cast)
            merge_to_bottom_hash(key, value)
          else
            add_to_bottom_of_hash(key, value)
          end
        else
          { key => value }
        end
      end

      def visit_Arel_Nodes_GreaterThan o, collector
        key = visit(o.left, collector)
        value = { :gt => visit(o.right, collector) }
        if key.is_a?(Hash)
          if o.left.is_a?(Arel::Attributes::Cast)
            merge_to_bottom_hash(key, value)
          else
            add_to_bottom_of_hash(key, value)
          end
        else
          { key => value }
        end
      end

      def visit_Arel_Nodes_LessThanOrEqual o, collector
        key = visit(o.left, collector)
        value = { :lte => visit(o.right, collector) }
        if key.is_a?(Hash)
          if o.left.is_a?(Arel::Attributes::Cast)
            merge_to_bottom_hash(key, value)
          else
            add_to_bottom_of_hash(key, value)
          end
        else
          { key => value }
        end
      end

      def visit_Arel_Nodes_LessThan o, collector
        key = visit(o.left, collector)
        value = { :lt => visit(o.right, collector) }
        if key.is_a?(Hash)
          if o.left.is_a?(Arel::Attributes::Cast)
            merge_to_bottom_hash(key, value)
          else
            add_to_bottom_of_hash(key, value)
          end
        else
          { key => value }
        end
      end

      # def visit_Arel_Nodes_Matches o, collector
      #   collector = visit o.left, collector
      #   collector << " LIKE "
      #   visit o.right, collector
      # end
      #
      # def visit_Arel_Nodes_DoesNotMatch o, collector
      #   collector = visit o.left, collector
      #   collector << " NOT LIKE "
      #   visit o.right, collector
      # end
      #
      def visit_Arel_Nodes_JoinSource o, collector
        if o.left
          collector.table = o.left.name if collector.is_a?(Arel::Collectors::Sunstone)
        end
        if o.right.any?
          # We need to visit the right to get remove bind values, but we don't
          # add it to the collector
          # collector << " " if o.left
          # collector = inject_join o.right, collector, ' '
          collector.join_source = inject_join(o.right, Arel::Collectors::Sunstone.new, ' ')
          # collector.join_source = Arel::Visitors::PostgreSQL.new(Arel::Collectors::SQLString.new).send(:inject_join, o.right, Arel::Collectors::SQLString.new, ' ')
        end
        collector
      end
      #
      # def visit_Arel_Nodes_Regexp o, collector
      #   raise NotImplementedError, '~ not implemented for this db'
      # end
      #
      # def visit_Arel_Nodes_NotRegexp o, collector
      #   raise NotImplementedError, '!~ not implemented for this db'
      # end
      #
      # def visit_Arel_Nodes_StringJoin o, collector
      #   visit o.left, collector
      # end
      #
      # def visit_Arel_Nodes_FullOuterJoin o
      #   "FULL OUTER JOIN #{visit o.left} #{visit o.right}"
      # end

      def visit_Arel_Nodes_OuterJoin o, collector
        collector = visit o.left, collector
        visit o.right, collector
      end

      # def visit_Arel_Nodes_RightOuterJoin o
      #   "RIGHT OUTER JOIN #{visit o.left} #{visit o.right}"
      # end

      def visit_Arel_Nodes_InnerJoin o, collector
        collector = visit o.left, collector
        if o.right
          visit(o.right, collector)
        else
          collector
        end
      end

      def visit_Arel_Nodes_On o, collector
        visit o.expr, collector
      end

      # def visit_Arel_Nodes_Not o, collector
      #   collector << "NOT ("
      #   visit(o.expr, collector) << ")"
      # end
      #
      def visit_Arel_Table o, collector
        if o.table_alias
          collector.table = o.table_alias if collector.is_a?(Arel::Collectors::Sunstone)
        else
          collector.table = o.name if collector.is_a?(Arel::Collectors::Sunstone)
        end
        collector
      end

      def visit_Arel_Nodes_In o, collector
        {
          visit(o.left, collector) => {in: visit(o.right, collector)}
        }
      end
      
      def visit_Arel_Nodes_NotIn o, collector
        {
          visit(o.left, collector) => {not_in: visit(o.right, collector)}
        }
      end
      
      def visit_Arel_Nodes_And o, collector
        ors = []
        
        o.children.each do |child, i|
          while child.is_a?(Arel::Nodes::Grouping)
            child = child.expr
          end
          value = visit(child, collector)
          if value.is_a?(Hash) && ors.last.is_a?(Hash) && !(value.keys - ors.last.keys).empty?
            ors.last.deep_merge!(value)
          else
            ors << value
          end
        end
        
        result = []
        ors.each_with_index do |c, i|
          result << c
          result << 'AND' if ors.size != i + 1
        end
        
        result.size == 1 ? result.first : result
      end
      
      def visit_Arel_Nodes_Or o, collector
        [visit(o.left, collector), 'OR', visit(o.right, collector)]
      end

      def visit_Arel_Nodes_Assignment o, collector
        case o.left
        when Arel::Nodes::UnqualifiedColumn
          { visit(o.left.expr, collector) => visit(o.right, collector) }
        when Arel::Attributes::Attribute, Arel::Nodes::BindParam
          { visit(o.left, collector) => visit(o.right, collector) }
        else
          collector = visit o.left, collector
          collector << " = "
          collector << quote(o.right, column_for(o.left)).to_s
        end
      end

      def merge_to_bottom_hash(hash, value)
        okey = hash
        while okey.values.first.is_a?(Hash)
          okey = okey.values.first
        end
        okey.merge!(value)
        hash
      end
      
      def add_to_bottom_of_hash(hash, value)
        okey = hash
        while okey.is_a?(Hash) && (okey.values.first.is_a?(Hash) || okey.values.first.is_a?(Array))
          if okey.is_a?(Array)
            okey = okey.find { |i| !i.nil? }
          else
            okey = okey.values.first
          end
        end
        nkey = okey.keys.first
        nvalue = okey.values.first
        okey[nkey] = { nvalue => value }
        hash
      end
      
      def visit_Arel_Nodes_Equality o, collector
        key = visit(o.left, collector)
        value = (o.right.nil? ? nil : visit(o.right, collector))
        
        if key.is_a?(Hash)
          add_to_bottom_of_hash(key, {eq: value})
        else
          key = key.to_s.split('.')
          hash = { key.pop => value }
          while key.size > 0
            hash = { key.pop => hash }
          end
          hash
        end
      end
      
      def visit_Arel_Nodes_TSMatch(o, collector)
        key = visit(o.left, collector)
        value = { ts_match: (o.right.nil? ? nil : visit(o.right, collector)) }

        if key.is_a?(Hash)
          add_to_bottom_of_hash(key, value)
        else
          key = key.to_s.split('.')
          hash = { key.pop => value }
          while key.size > 0
            hash = { key.pop => hash }
          end
          hash
        end
      end
      
      def visit_Arel_Nodes_TSVector(o, collector)
        visit(o.attribute, collector)
      end
      
      def visit_Arel_Nodes_TSQuery(o, collector)
        if o.language
          [visit(o.expression, collector), visit(o.language, collector)]
        else
          visit(o.expression, collector)
        end
      end
      
      def visit_Arel_Nodes_HasKey o, collector
        key = visit(o.left, collector)
        value = {has_key: (o.right.nil? ? nil : o.right.to_s)}
        
        if key.is_a?(Hash)
          okey = key
          while okey.values.first.is_a?(Hash)
            okey = okey.values.first
          end
          nkey = okey.keys.first
          nvalue = okey.values.first
          okey[nkey] = { nvalue => value }
        else
          { key => value }
        end
      end
      
      def visit_Arel_Nodes_NotEqual o, collector
        {
          visit(o.left, collector) => { :not => visit(o.right, collector) }
        }
      end

      def visit_Arel_Nodes_As o, collector
        # collector = visit o.left, collector
        # collector << " AS "
        # visit o.right, collector
        collector
      end

      def visit_Arel_Nodes_UnqualifiedColumn o, collector
        o.name
      end
      
      def visit_Arel_Attributes_Cast(o, collector)
        visit(o.relation, collector) # No casting yet
      end
      
      def visit_Arel_Attributes_Key o, collector
        key = visit(o.relation, collector)
        if key.is_a?(Hash)
          okey = key
          while okey.values.first.is_a?(Hash)
            okey = okey.values.first
          end
          nkey = okey.keys.first
          value = okey.values.first
          okey[nkey] = {value => o.name}
          key
        else
          { key => o.name }
        end
      end

      def visit_Arel_Attributes_Relation o, collector, top=true
        value = if o.relation.is_a?(Arel::Attributes::Relation)
          visit_Arel_Attributes_Relation(o.relation, collector, false)
        else
          visit(o.relation, collector)
        end
        value = value.to_s.split('.').last if !value.is_a?(Hash)

        if o.collection
          ary = []
          ary[o.collection] = value
          if top && o.name == collector.table
            ary
          elsif o.for_write
            {"#{o.name}_attributes" => ary}
          else
            {o.name => ary}
          end
        else
          if top && o.name == collector.table
            value
          elsif o.for_write
            {"#{o.name}_attributes" => value}
          else
            {o.name => value}
          end
        end
      end

      def visit_Arel_Attributes_EmptyRelation o, collector, top=true
        o.for_write ? "#{o.name}_attributes" : o.name
      end
      
      def visit_Arel_Attributes_Attribute o, collector
        join_name = o.relation.table_alias || o.relation.name
        collector.table == join_name ? o.name : "#{join_name}.#{o.name}" if collector.is_a?(Arel::Collectors::Sunstone)
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def visit_Arel_Nodes_BindParam o, collector
        o
      end

      def literal(o, collector)
        o
      end
      alias :visit_Arel_Nodes_SqlLiteral :literal
      alias :visit_Bignum                :literal
      alias :visit_Fixnum                :literal
      alias :visit_Integer               :literal
      #
      # def quoted o, a
      #   quote(o, column_for(a))
      # end
      #
      # def unsupported o, collector
      #   raise "unsupported: #{o.class.name}"
      # end
      #
      # alias :visit_ActiveSupport_Multibyte_Chars :unsupported
      # alias :visit_ActiveSupport_StringInquirer  :unsupported
      # alias :visit_BigDecimal                    :unsupported
      # alias :visit_Class                         :unsupported
      # alias :visit_Date                          :unsupported
      # alias :visit_DateTime                      :unsupported
      # alias :visit_FalseClass                    :unsupported
      # alias :visit_Float                         :unsupported
      # alias :visit_Hash                          :unsupported
      # alias :visit_NilClass                      :unsupported
      # alias :visit_String                        :unsupported
      # alias :visit_Symbol                        :unsupported
      # alias :visit_Time                          :unsupported
      # alias :visit_TrueClass                     :unsupported
      #
      # def visit_Arel_Nodes_InfixOperation o, collector
      #   collector = visit o.left, collector
      #   collector << " #{o.operator} "
      #   visit o.right, collector
      # end
      #
      # alias :visit_Arel_Nodes_Addition       :visit_Arel_Nodes_InfixOperation
      # alias :visit_Arel_Nodes_Subtraction    :visit_Arel_Nodes_InfixOperation
      # alias :visit_Arel_Nodes_Multiplication :visit_Arel_Nodes_InfixOperation
      # alias :visit_Arel_Nodes_Division       :visit_Arel_Nodes_InfixOperation

      def visit_Array o, collector
        o.map { |x| visit(x, collector) }
      end

      # def quote value, column = nil
      #   return value if Arel::Nodes::SqlLiteral === value
      #   @connection.quote value, column
      # end
      #
      # def quote_table_name name
      #   return name if Arel::Nodes::SqlLiteral === name
      #   @quoted_tables[name] ||= @connection.quote_table_name(name)
      # end
      #
      # def quote_column_name name
      #   @quoted_columns[name] ||= Arel::Nodes::SqlLiteral === name ? name : @connection.quote_column_name(name)
      # end
      #
      # def maybe_visit thing, collector
      #   return collector unless thing
      #   collector << " "
      #   visit thing, collector
      # end

      def inject_join list, collector, join_str
        len = list.length - 1
        list.each_with_index.inject(collector) { |c, (x,i)|
          visit x, c
        }
      end

      # def infix_value o, collector, value
      #   collector = visit o.left, collector
      #   collector << value
      #   visit o.right, collector
      # end
      #
      def aggregate name, o, collector
        collector << "#{name}("
        if o.distinct
          collector << "DISTINCT "
        end
        collector = inject_join(o.expressions, Arel::Collectors::Sunstone.new, ", ")# << ")"
        if o.alias
          collector << " AS "
          visit o.alias, collector
        else
          collector
        end
      end
      
      def maybe_visit thing, collector
        return collector unless thing
        collector << " "
        visit thing, collector
      end
    end
  end
end
