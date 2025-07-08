# Record the dao events parsed from transactions
# See: https://github.com/shaojunda/Nervos-DAO-RFC/blob/master/README.md
class DaoEvent < ApplicationRecord
  # withdraw_phase_1: withdraw_from_dao
  # withdraw_phase_2: issue_interest
  enum event_type: {
    deposit_to_dao: 0,
    withdraw_from_dao: 2,
    issue_interest: 3,
  }
  enum status: { pending: 0, processed: 1, reverted: 2 }
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }

  belongs_to :block
  belongs_to :ckb_transaction
  belongs_to :address
  belongs_to :consumed_transaction, class_name: "CkbTransaction", optional: true
  belongs_to :cell_output, optional: true

  scope :depositor, -> { processed.where(event_type: "deposit_to_dao", consumed_transaction_id: nil) }
  scope :created_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :created_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }
  scope :created_between, ->(start_block_timestamp, end_block_timestamp) {
                            created_after(start_block_timestamp).created_before(end_block_timestamp)
                          }
end

# == Schema Information
#
# Table name: dao_events
#
#  id                       :bigint           not null, primary key
#  block_id                 :bigint
#  ckb_transaction_id       :bigint
#  address_id               :bigint
#  contract_id              :bigint
#  event_type               :integer
#  value                    :decimal(30, )    default(0)
#  status                   :integer          default("pending")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  block_timestamp          :decimal(30, )
#  consumed_transaction_id  :bigint
#  cell_index               :integer
#  consumed_block_timestamp :decimal(20, )
#  cell_output_id           :bigint
#
# Indexes
#
#  index_dao_events_on_block_id                           (block_id)
#  index_dao_events_on_block_id_tx_id_and_index_and_type  (block_id,ckb_transaction_id,cell_index,event_type) UNIQUE
#  index_dao_events_on_block_timestamp                    (block_timestamp)
#  index_dao_events_on_status_and_event_type              (status,event_type)
#
