module ActiveRecord
  # = Active Record \Persistence
  module Persistence
    private

    def create_or_update(*args)
      raise ReadOnlyRecord, "#{self.class} is marked as readonly" if readonly?
      result = new_record? ? _create_record : _update_record(*args)
      result != false
    rescue Sunstone::Exception::BadRequest => e
      JSON.parse(e.message)['errors'].each do |field, message|
        if message.is_a?(Array)
          message.each { |m| errors.add(field, m) }
        else
          errors.add(field, message)
        end
      end
      raise ActiveRecord::RecordInvalid
    end
  end
end