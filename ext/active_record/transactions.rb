require 'active_record'
require 'active_record/transactions'

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
    def save!(*) #:nodoc:
      if instance_variable_defined?(:@no_save_transaction) && @no_save_transaction
        super
      else
        with_transaction_returning_status { super }
      end
    end
    
    #
    # def touch(*) #:nodoc:
    #   with_transaction_returning_status { super }
    # end

    def with_transaction_returning_status
      status = nil
      
      if self.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && instance_variable_defined?(:@updating) && @updating
        status = yield
        status
      else
        self.class.transaction do
          if has_transactional_callbacks?
            add_to_transaction
          else
            sync_with_transaction_state if @transaction_state&.finalized?
            @transaction_state = self.class.connection.transaction_state
          end
          remember_transaction_record_state

          status = yield
          raise ActiveRecord::Rollback unless status
        end
        status
      end
    ensure
      if @transaction_state && @transaction_state.committed?
        clear_transaction_record_state
      end
    end


  end
end
