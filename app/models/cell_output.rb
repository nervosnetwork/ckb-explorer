class CellOutput < ApplicationRecord
  SYSTEM_TX_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000".freeze
  MAXIMUM_DOWNLOADABLE_SIZE = 64000
  MIN_SUDT_AMOUNT_BYTESIZE = 16
  enum status: { live: 0, dead: 1 }
  enum cell_type: { normal: 0, nervos_dao_deposit: 1, nervos_dao_withdrawing: 2, udt: 3, m_nft_issuer: 4, m_nft_class:5, m_nft_token: 6 }

  belongs_to :ckb_transaction
  belongs_to :generated_by, class_name: "CkbTransaction"
  belongs_to :consumed_by, class_name: "CkbTransaction", optional: true
  belongs_to :address
  belongs_to :block
  # belongs_to :lock_script, optional: true
  # belongs_to :type_script, optional: true

  validates :capacity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  attribute :tx_hash, :ckb_hash

  scope :consumed_after, ->(block_timestamp) { where("consumed_block_timestamp >= ?", block_timestamp) }
  scope :consumed_before, ->(block_timestamp) { where("consumed_block_timestamp <= ?", block_timestamp) }
  scope :unconsumed_at, ->(block_timestamp) { where("consumed_block_timestamp > ? or consumed_block_timestamp = 0", block_timestamp) }
  scope :generated_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :generated_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }

  after_commit :flush_cache

  # will remove this method after the migration task processed
  def lock_script
    LockScript.find_by(cell_output_id: id) || LockScript.find_by(id: lock_script_id)
  end

  # will remove this method after the migration task processed
  def type_script
    TypeScript.find_by(cell_output_id: id) || TypeScript.find_by(id: type_script_id)
  end

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
    CkbUtils.hash_value_to_s(
      symbol: udt_info&.symbol, amount: udt_amount, decimal: udt_info&.decimal, type_hash: type_hash, published: !!udt_info&.published
    )
  end

  def m_nft_info
    return unless cell_type.in?(%w(m_nft_issuer m_nft_class m_nft_token))

    case cell_type
    when "m_nft_issuer"
      value = { issuer_name: CkbUtils.parse_issuer_data(data).info["name"] }
    when "m_nft_class"
      parsed_data = CkbUtils.parse_token_class_data(data)
      value = { class_name: parsed_data.name, total: parsed_data.total }
    when "m_nft_token"
      # issuer_id size is 20 bytes, class_id size is 4 bytes
      m_nft_class_type = TypeScript.where(code_hash: CkbSync::Api.instance.token_class_script_code_hash, args: type_script.args[0..49]).first
      if m_nft_class_type.present?
        m_nft_class_cell = m_nft_class_type.cell_outputs.last
        parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
        value = { class_name: parsed_class_data.name, token_id: type_script.args[50..-1], total: parsed_class_data.total }
      else
        value = { class_name: "", token_id: "", total: "" }
      end
    else
      raise RuntimeError.new("invalid cell type")
    end
    CkbUtils.hash_value_to_s(value)
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
#  dao                      :string
#  lock_script_id           :bigint
#  type_script_id           :bigint
#
# Indexes
#
#  index_cell_outputs_on_address_id_and_status     (address_id,status)
#  index_cell_outputs_on_block_id                  (block_id)
#  index_cell_outputs_on_block_timestamp           (block_timestamp)
#  index_cell_outputs_on_ckb_transaction_id        (ckb_transaction_id)
#  index_cell_outputs_on_consumed_block_timestamp  (consumed_block_timestamp)
#  index_cell_outputs_on_consumed_by_id            (consumed_by_id)
#  index_cell_outputs_on_generated_by_id           (generated_by_id)
#  index_cell_outputs_on_lock_script_id            (lock_script_id)
#  index_cell_outputs_on_status                    (status)
#  index_cell_outputs_on_tx_hash_and_cell_index    (tx_hash,cell_index)
#  index_cell_outputs_on_type_script_id            (type_script_id)
#
