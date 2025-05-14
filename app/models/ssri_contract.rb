class SsriContract < ApplicationRecord
  belongs_to :contract

  scope :udt, -> { where(is_udt: true) }
end

# == Schema Information
#
# Table name: ssri_contracts
#
#  id          :bigint           not null, primary key
#  contract_id :bigint
#  methods     :string           default([]), is an Array
#  is_udt      :boolean
#  code_hash   :binary
#  hash_type   :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_ssri_contracts_on_contract_id  (contract_id) UNIQUE
#
