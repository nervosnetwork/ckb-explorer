module Uuidable
  extend ActiveSupport::Concern

  included do
    before_validation do
      if new_record? && uuid.blank?
        begin
          uuid = SecureRandom.uuid
        end while self.class.where(uuid:).exists?

        write_attribute(:uuid, uuid)
      end
    end
  end
end
