class ActiveRecord::Associations::CollectionAssociation::HasManyThroughAssociation

  private

  def save_through_record(record)
    return if record.sunstone?
    
    association = build_through_record(record)
    if association.changed?
      association.save!
    end
  ensure
    @through_records.delete(record.object_id)
  end

end