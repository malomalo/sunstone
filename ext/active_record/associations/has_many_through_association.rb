# frozen_string_literal: true

# The last ref that this code was synced with Rails
# ref: 90a1eaa1b3

class ActiveRecord::Associations::CollectionAssociation::HasManyThroughAssociation

  private

  def save_through_record(record)
    return if record.sunstone?
    
    association = build_through_record(record)
    if association.changed?
      association.save!
    end
  ensure
    @through_records.delete(record)
  end

end