require 'sunstone/model/attributes'
require 'sunstone/model/associations'
require 'sunstone/model/persistence'

module Sunstone
  class Model
    
    extend ActiveModel::Naming
    include ActiveModel::Conversion
    
    include Sunstone::Model::Attributes
    include Sunstone::Model::Associations
    include Sunstone::Model::Persistence
    
    def initialize(attrs={})
      super
      attrs.each do |k, v|
        self.send(:"#{k}=", v)
      end
    end
    
  end
end