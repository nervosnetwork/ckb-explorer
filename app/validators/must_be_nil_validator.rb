class MustBeNilValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value
      record.errors.add(attribute, "must be nil")
    end
  end
end
