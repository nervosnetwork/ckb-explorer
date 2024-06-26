class UdtHolderAllocation < ApplicationRecord
  belongs_to :udt
  belongs_to :contract, optional: true
end

# == Schema Information
#
# Table name: udt_holder_allocations
#
#  id               :bigint           not null, primary key
#  udt_id           :bigint           not null
#  contract_id      :bigint
#  ckb_holder_count :integer          default(0), not null
#  btc_holder_count :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_udt_holder_allocations_on_udt_id  (udt_id)
#
