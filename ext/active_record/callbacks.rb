# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

module ActiveRecord
  module Callbacks
    private

      def create_or_update(**) #:nodoc:
        if self.sunstone?
          @_already_called ||= {}
          self.class.reflect_on_all_associations.each do |r|
            @_already_called[:"autosave_associated_records_for_#{r.name}"] = true
          end
        end

        _run_save_callbacks { super }
      end

  end
end
