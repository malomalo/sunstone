module Sunstone
  module Type
    module Mutable # :nodoc:
      def type_cast_from_user(value)
        type_cast_from_json(type_cast_for_json(value))
      end

      # +raw_old_value+ will be the `_before_type_cast` version of the
      # value (likely a string). +new_value+ will be the current, type
      # cast value.
      def changed_in_place?(raw_old_value, new_value)
        raw_old_value != type_cast_for_json(new_value)
      end
    end
  end
end
