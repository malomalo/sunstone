require 'sunstone/model/attributes'
require 'sunstone/model/associations'

module Sunstone
  class Model
    
    extend ActiveModel::Naming
    
    include Sunstone::Model::Attributes
    include Sunstone::Model::Associations
    
    
    def initialize(attrs={})
      super
      attrs.each do |k, v|
        self.send(:"#{k}=", v)
      end
    end
    
    def self.find(id)
      Sunstone.get("/#{self.model_name.route_key}/#{id}") do |response|
        Sunstone::Parser.parse(self, response)
      end
    end
    
  end
end