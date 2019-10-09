class DaoEvent < ApplicationRecord
  enum event_type: { deposit_to_dao: 0, new_dao_depositor: 1 }
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }

  belongs_to :block
  belongs_to :ckb_transaction
  belongs_to :address
end

# == Schema Information
#
# Table name: dao_events
#
#  id                 :bigint           not null, primary key
#  block_id           :bigint
#  ckb_transaction_id :bigint
#  address_id         :bigint
#  contract_id        :bigint
#  event_type         :integer
#  value              :decimal(30, )    default(0)
#  status             :integer          default(0)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_dao_events_on_block_id  (block_id)
#
