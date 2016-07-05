module ActiveRecord
  # See ActiveRecord::Transactions::ClassMethods for documentation.
  module Transactions

    # # See ActiveRecord::Transactions::ClassMethods for detailed documentation.
    # def transaction(options = {}, &block)
    #   self.class.transaction(options, &block)
    # end
    #
    # def destroy #:nodoc:
    #   with_transaction_returning_status { super }
    # end
    #
    # def save(*) #:nodoc:
    #   rollback_active_record_state! do
    #     with_transaction_returning_status { super }
    #   end
    # end
    #
    # def save!(*) #:nodoc:
    #   with_transaction_returning_status { super }
    # end
    #
    # def touch(*) #:nodoc:
    #   with_transaction_returning_status { super }
    # end

    def with_transaction_returning_status
      if self.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && @updating
        begin
          status = yield
        rescue ActiveRecord::Rollback
          clear_transaction_record_state
          status = nil
        end
        return status
      end
      
      status = nil
      self.class.transaction do
        add_to_transaction
        begin
          status = yield
        rescue ActiveRecord::Rollback
          clear_transaction_record_state
          status = nil
        end
        
        raise ActiveRecord::Rollback unless status
      end
      status
    ensure
      if @transaction_state && @transaction_state.committed?
        clear_transaction_record_state
      end
    end


  end
end
