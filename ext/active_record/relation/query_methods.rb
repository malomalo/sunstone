# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

module ActiveRecord
  module QueryMethods
    private

    def assert_modifiable!
      raise UnmodifiableRelation if @loaded
      raise UnmodifiableRelation if @arel && !model.sunstone?
    end

  end
end