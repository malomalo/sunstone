class ActiveRecord::Base
  
  def self.sunstone?
    connection_pool.db_config.adapter_class == ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter
  end
  
  def sunstone?
    self.class.sunstone?
  end
  
end
