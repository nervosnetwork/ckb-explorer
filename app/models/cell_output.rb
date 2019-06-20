class CellOutput < ApplicationRecord
  SYSTEM_TX_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000".freeze

  enum status: { live: 0, dead: 1 }
  enum cell_type: { normal: 0, dao: 1 }

  belongs_to :ckb_transaction
  belongs_to :generated_by, class_name: "CkbTransaction"
  belongs_to :consumed_by, class_name: "CkbTransaction", optional: true
  belongs_to :address
  belongs_to :block
  has_one :lock_script, dependent: :delete
  has_one :type_script, dependent: :delete

  validates :capacity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  attribute :tx_hash, :ckb_hash

  after_commit :flush_cache

  def address_hash
    address.address_hash
  end

  def node_output
    lock = CKB::Types::Script.new(lock_script.to_node_lock)
    type = type_script.present? ? CKB::Types::Script.new(type_script.to_node_lock) : nil
    CKB::Types::Output.new(capacity: capacity.to_i, lock: lock, type: type)
  end

  def flush_cache
    Rails.cache.delete("previous_cell_output/#{tx_hash}/#{cell_index}")
  end

  def cache_key
    "#{self.class.name}/#{id}-#{updated_at.utc.to_s(:usec)}"
  end
end

# == Schema Information
#
# Table name: cell_outputs
#
#  id                 :bigint           not null, primary key
#  capacity           :decimal(64, 2)
#  data               :binary
#  ckb_transaction_id :bigint
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  status             :integer          default("live")
#  address_id         :decimal(30, )
#  block_id           :decimal(30, )
#  tx_hash            :binary
#  cell_index         :integer
#  generated_by_id    :decimal(30, )
#  consumed_by_id     :decimal(30, )
#  cell_type          :integer          default("normal")
#
# Indexes
#
#  index_cell_outputs_on_address_id_and_status   (address_id,status)
#  index_cell_outputs_on_block_id                (block_id)
#  index_cell_outputs_on_ckb_transaction_id      (ckb_transaction_id)
#  index_cell_outputs_on_consumed_by_id          (consumed_by_id)
#  index_cell_outputs_on_generated_by_id         (generated_by_id)
#  index_cell_outputs_on_tx_hash_and_cell_index  (tx_hash,cell_index)
#
