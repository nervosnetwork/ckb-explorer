class UdtVerification < ApplicationRecord
end

# == Schema Information
#
# Table name: udt_verifications
#
#  id            :bigint           not null, primary key
#  token         :integer
#  sent_at       :datetime
#  last_ip       :inet
#  udt_id        :bigint
#  udt_type_hash :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_udt_verifications_on_udt_id         (udt_id)
#  index_udt_verifications_on_udt_type_hash  (udt_type_hash) UNIQUE
#
