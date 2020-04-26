class CellOutput < ApplicationRecord
  SYSTEM_TX_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000".freeze
  MAXIMUM_DOWNLOADABLE_SIZE = 64000
  enum status: { live: 0, dead: 1 }
  enum cell_type: { normal: 0, nervos_dao_deposit: 1, nervos_dao_withdrawing: 2, udt: 3 }

  belongs_to :ckb_transaction
  belongs_to :generated_by, class_name: "CkbTransaction"
  belongs_to :consumed_by, class_name: "CkbTransaction", optional: true
  belongs_to :address
  belongs_to :block
  has_one :lock_script, dependent: :delete
  has_one :type_script, dependent: :delete

  validates :capacity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  attribute :tx_hash, :ckb_hash

  scope :consumed_after, ->(block_timestamp) { where("consumed_block_timestamp >= ?", block_timestamp) }
  scope :consumed_before, ->(block_timestamp) { where("consumed_block_timestamp <= ?", block_timestamp) }
  scope :unconsumed_at, ->(block_timestamp) { where("consumed_block_timestamp > ? or consumed_block_timestamp is null", block_timestamp) }
  scope :generated_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :generated_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }

  after_commit :flush_cache

  def address_hash
    address.address_hash
  end

  def node_output
    lock = CKB::Types::Script.new(lock_script.to_node_lock)
    type = type_script.present? ? CKB::Types::Script.new(type_script.to_node_type) : nil
    CKB::Types::Output.new(capacity: capacity.to_i, lock: lock, type: type)
  end

  def cache_keys
    %W(
      previous_cell_output/#{tx_hash}/#{cell_index} normal_tx_display_inputs_previews_true_#{ckb_transaction_id}
      normal_tx_display_inputs_previews_false_#{ckb_transaction_id} normal_tx_display_inputs_previews_true_#{consumed_by_id}
      normal_tx_display_inputs_previews_false_#{consumed_by_id} normal_tx_display_outputs_previews_true_#{ckb_transaction_id}
      normal_tx_display_outputs_previews_false_#{ckb_transaction_id} normal_tx_display_outputs_previews_true_#{consumed_by_id}
      normal_tx_display_outputs_previews_false_#{consumed_by_id}
    )
  end

  def udt_info
    return unless udt?

    udt_info = Udt.find_by(type_hash: type_hash, published: true)
    CkbUtils.hash_value_to_s({
      symbol: udt_info&.symbol, amount: udt_amount, decimal: udt_info&.decimal, type_hash: type_hash, published: !!udt_info&.published
    })
  end

  def flush_cache
    $redis.pipelined do
      $redis.del(*cache_keys)
    end
  end
end

# == Schema Information
#
# Table name: cell_outputs
#
#  id                       :bigint           not null, primary key
#  capacity                 :decimal(64, 2)
#  data                     :binary
#  ckb_transaction_id       :bigint
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  status                   :integer          default("live")
#  address_id               :decimal(30, )
#  block_id                 :decimal(30, )
#  tx_hash                  :binary
#  cell_index               :integer
#  generated_by_id          :decimal(30, )
#  consumed_by_id           :decimal(30, )
#  cell_type                :integer          default("normal")
#  data_size                :integer
#  occupied_capacity        :decimal(30, )
#  block_timestamp          :decimal(30, )
#  consumed_block_timestamp :decimal(30, )
#  type_hash                :string
#  udt_amount               :decimal(40, )
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
