# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

class ActiveRecord::Base
  
  def self.sunstone?
    connection_pool.db_config.adapter_class == ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter
  end
  
  def sunstone?
    self.class.sunstone?
  end
  
end
