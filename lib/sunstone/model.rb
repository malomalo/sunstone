require 'sunstone/model/attributes'
require 'sunstone/model/associations'

module Sunstone
  class Model
    
    include Sunstone::Model::Attributes
    include Sunstone::Model::Associations
    
    def initialize(attrs={})
      super
      attrs.each do |k, v|
        self.send(:"#{k}=", v)
      end
    end
    
  end
end