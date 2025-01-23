module ActiveRecord
  module QueryMethods
    private

    def assert_modifiable!
      raise UnmodifiableRelation if @loaded
      raise UnmodifiableRelation if @arel && !model.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
    end

    # I'm not sure why but the .to_s was introduced by this
    # PR: https://github.com/rails/rails/pull/53625
    # which break sunstone which needs the hash to pass through
    def arel_column(field)
      field = field.name if is_symbol = field.is_a?(Symbol)

      field = model.attribute_aliases[field] || (field.is_a?(Hash) ? field : field.to_s)
      from = from_clause.name || from_clause.value

      if field.is_a?(Hash)
        field
      elsif model.columns_hash.key?(field) && (!from || table_name_matches?(from))
        table[field]
      elsif /\A(?<table>(?:\w+\.)?\w+)\.(?<column>\w+)\z/ =~ field
        arel_column_with_table(table, column)
      elsif block_given?
        yield field
      elsif Arel.arel_node?(field)
        field
      else
        Arel.sql(is_symbol ? model.adapter_class.quote_table_name(field) : field)
      end
    end
    
  end
end