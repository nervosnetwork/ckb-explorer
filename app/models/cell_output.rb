class CellOutput < ApplicationRecord
  enum status: { live: 0, dead: 1, abandoned: 2 }

  belongs_to :ckb_transaction
  belongs_to :address
  belongs_to :block
  has_one :lock_script
  has_one :type_script

  validates :capacity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  attribute :tx_hash, :ckb_hash

  scope :available, -> { where(status: [:live, :dead]) }

  after_commit :flush_cache

  def address_hash
    address.address_hash
  end

  def flush_cache
    Rails.cache.delete([self.class.name, tx_hash, cell_index])
    Rails.cache.delete([self.class.name, tx_hash, "lock_script"])
    Rails.cache.delete([self.class.name, tx_hash, "type_script"])
  end

  def self.cached_find(id)
    Rails.cache.fetch([name, id], race_condition_ttl: 3.seconds) do
      CellOutput.where(id: id).available.take!
    end
  end

  def cached_lock_script
    Rails.cache.fetch([self.class.name, tx_hash, "lock_script"], race_condition_ttl: 3.seconds) { lock_script }
  end

  def cached_type_script
    Rails.cache.fetch([self.class.name, tx_hash, "type_script"], race_condition_ttl: 3.seconds) { type_script }
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
#
# Indexes
#
#  index_cell_outputs_on_address_id_and_status   (address_id,status)
#  index_cell_outputs_on_block_id                (block_id)
#  index_cell_outputs_on_ckb_transaction_id      (ckb_transaction_id)
#  index_cell_outputs_on_tx_hash_and_cell_index  (tx_hash,cell_index)
#
