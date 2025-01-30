# frozen_string_literal: true

module ActiveRecord
  module Locking
    module Optimistic
      
      private

        def _update_row(attribute_names, attempted_action = "update")
          return super unless locking_enabled?

          begin
            locking_column = self.class.locking_column
            lock_attribute_was = @attributes[locking_column]

            update_constraints = _query_constraints_hash

            attribute_values = if attribute_names.is_a?(Hash)
              attribute_names.merge(attributes_with_values([locking_column]))
            else
              attribute_names = attribute_names.dup if attribute_names.frozen?
              attribute_names << locking_column
              attributes_with_values(attribute_names)
            end

            self[locking_column] += 1

            # Suntone returns the row(s) not a int of afftecd_rows
            result = self.class._update_record(
              attribute_values,
              update_constraints
            )
            affected_rows = sunstone? ? result.rows.size : result

            if affected_rows != 1
              raise ActiveRecord::StaleObjectError.new(self, attempted_action)
            end

            affected_rows

          # If something went wrong, revert the locking_column value.
          rescue Exception
            @attributes[locking_column] = lock_attribute_was
            raise
          end
        end

    end
  end
end
