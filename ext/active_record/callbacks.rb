module ActiveRecord
  module Callbacks
    private

      def create_or_update(*) #:nodoc:
        if self.class.connection.is_a?(ActiveRecord::ConnectionAdapters::SunstoneAPIAdapter)
          @_already_called ||= {}
          self.class.reflect_on_all_associations.each do |r|
            @_already_called[:"autosave_associated_records_for_#{r.name}"] = true
          end
        end

        _run_save_callbacks { super }
      end

  end
end