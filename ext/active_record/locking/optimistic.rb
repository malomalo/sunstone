# frozen_string_literal: true

module ActiveRecord
  module Locking
    module Optimistic
      
      private

        def _update_row(attribute_values, attempted_action = "update")
          return super unless locking_enabled?

          begin
            locking_column = self.class.locking_column
            lock_attribute_was = @attributes[locking_column]

            update_constraints = _query_constraints_hash

            self[locking_column] += 1

            attribute_values = if attribute_values.is_a?(Hash)
              attribute_values.merge(attributes_with_values([locking_column]))
            else
              attribute_values = attribute_values.dup if attribute_values.frozen?
              attribute_values << locking_column
              attributes_with_values(attribute_values)
            end

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
