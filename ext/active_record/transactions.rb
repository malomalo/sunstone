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
    def save!(**) #:nodoc:
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
      self.class.with_connection do |connection|
        status = nil
        # connection = self.class.connection

        if connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter) && instance_variable_defined?(:@sunstone_updating) && @sunstone_updating
          status = yield
        else
          ensure_finalize = !connection.transaction_open?
          connection.transaction do
            add_to_transaction(ensure_finalize || has_transactional_callbacks?)
            remember_transaction_record_state

            status = yield
            raise ActiveRecord::Rollback unless status
          end
        end
      
        status
      end
    end


  end
end
