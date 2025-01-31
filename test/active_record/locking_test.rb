require 'test_helper'

class ActiveRecord::OptimisticLockingTest < ActiveSupport::TestCase

  schema do
    
    create_table :locks do |t|
      t.string :name
      t.integer :lock_version
    end
    
  end
  
  class Lock < ActiveRecord::Base
  end
  

  # Test comes from Rails, one day use rails test agains sunstone?
  test 'count for a composite primary key model with includes and references' do
    webmock(:get, "/locks", { where: {id: 1}, limit: 1 }).to_return(body: [{
      id: 1, lock_version: 0
    }].to_json)
    webmock(:patch, "/locks/1", { where: {lock_version: 0} }).to_return(body: [].to_json)

    s1 = Lock.find(1)
    assert Lock.locking_enabled?
    assert_equal 0, s1.lock_version

    s1.name = "doubly updated record"
    assert_raise(ActiveRecord::StaleObjectError) { s1.save! }
  end

end