module Sunstone
  class Parser < Wankel::SaxParser
    
    attr_reader :object
    
    def self.parse(klass, response_or_body)
      parser = self.new(klass)
      
      if response_or_body.is_a?(Net::HTTPResponse)
        response_or_body.read_body do |chunk|
          parser << chunk
        end
      else
        parser << response_or_body
      end
      
      parser.complete
    end
  
    def initialize(klass, options=nil)
      super(options)
      
      @object = klass.new
      @stack = []
    end

    def on_map_start
      if @stack.size == 0
        @stack << @object
      elsif @stack.last.is_a?(Array)
        key = @stack[-2].to_sym
        if @stack[-3].reflect_on_associations[key]
          @stack << @stack[-3].reflect_on_associations[key][:klass].new
        end
      else
        key = @stack.last.to_sym
        if @stack[-2].reflect_on_associations[key]
          @stack << @stack[-2].reflect_on_associations[key][:klass].new
        end
      end
    end
  
    def on_map_end
      value = @stack.pop
      
      on_value(value) if @stack.size > 0
      
      value
    end
  
    def on_map_key(key)
      @stack << key
    end
  
    def on_value(value)
      if @stack.last.is_a?(Array)
        @stack.last << value
      else
        attribute = @stack.pop
        @stack.last.send(:"#{attribute}=", value) if @stack.last.respond_to?(:"#{attribute}=")
      end
    end
  
    def on_null; on_value(nil) ;end
    alias :on_boolean :on_value
    alias :on_integer :on_value
    alias :on_double  :on_value
    alias :on_string  :on_value
  
    def on_array_start
        @stack << Array.new
    end
  
    def on_array_end
      value = @stack.pop
      attribute = @stack.pop
      @stack.last.send(:"#{attribute}=", value) if @stack.last.respond_to?(:"#{attribute}=")
    end
  
    # Override to return the account
    def parse(*args, &block)
      super(*args, &block)
      @object
    end
  
    # Override to return the account
    def complete
      super
      @object
    end
    
  end
end