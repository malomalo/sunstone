# frozen_string_literal: true

class NilClass
  
  def to_query(namespace)
    namespace.to_s
  end
  
end

class Hash
  
  def to_query(namespace = nil)
    collect do |key, value|
      # unless (value.is_a?(Hash) || value.is_a?(Array)) && value.empty?
        value.to_query(namespace ? "#{namespace}[#{key}]" : key)
      # end
    end.compact.sort! * '&'
  end

  alias_method :to_param, :to_query
end