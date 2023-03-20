class CellOutput < ApplicationRecord
  SYSTEM_TX_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000".freeze
  MAXIMUM_DOWNLOADABLE_SIZE = 64000
  MIN_SUDT_AMOUNT_BYTESIZE = 16
  enum status: { live: 0, dead: 1 }
  enum cell_type: { normal: 0, nervos_dao_deposit: 1, nervos_dao_withdrawing: 2, udt: 3, m_nft_issuer: 4, m_nft_class: 5, m_nft_token: 6, nrc_721_token: 7, nrc_721_factory: 8, cota_registry: 9, cota_regular: 10 }

  belongs_to :ckb_transaction
  belongs_to :generated_by, class_name: "CkbTransaction"
  belongs_to :consumed_by, class_name: "CkbTransaction", optional: true
  belongs_to :address
  belongs_to :deployed_cell, optional: true
  belongs_to :block
  belongs_to :lock_script, optional: true
  belongs_to :type_script, optional: true

  has_many :cell_dependencies, foreign_key: :contract_cell_id, dependent: :delete_all
  has_many :referring_cells

  validates :capacity, presence: true, numericality: { greater_than_or_equal_to: 0 }

  attribute :tx_hash, :ckb_hash

  scope :consumed_after, ->(block_timestamp) { where("consumed_block_timestamp >= ?", block_timestamp) }
  scope :consumed_before, ->(block_timestamp) { where("consumed_block_timestamp <= ?", block_timestamp) }
  scope :unconsumed_at, ->(block_timestamp) { where("consumed_block_timestamp > ? or consumed_block_timestamp = 0", block_timestamp) }
  scope :generated_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :generated_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }
  scope :inner_block, ->(block_id) { where("block_id = ?", block_id) }
  scope :free, -> { where(type_hash: nil, data: "0x") }
  scope :occupied, -> { where.not(type_hash: nil, data: "0x") }

  after_commit :flush_cache

  def occupied?
    !free?
  end

  def free?
    type_hash.blank? && (data.present? && data == "0x")
  end

  def address_hash
    address.address_hash
  end

  def self.find_by_pointer(tx_hash, index)
    tx = CkbTransaction.find_by_tx_hash(tx_hash)
    find_by(generated_by_id: tx.id, cell_index: index.is_a?(String) ? index.hex : index) if tx
  end

  def node_output
    lock = CKB::Types::Script.new(**lock_script.to_node)
    type = type_script.present? ? CKB::Types::Script.new(**type_script.to_node) : nil
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

  def to_raw
    {
      capacity: "0x#{capacity.to_i.to_s(16)}",
      lock: lock_script&.to_node,
      type: type_script&.to_node
    }
  end

  def udt_info
    return unless udt?

    udt_info = Udt.find_by(type_hash: type_hash, published: true)
    CkbUtils.hash_value_to_s(
      symbol: udt_info&.symbol,
      amount: udt_amount,
      decimal: udt_info&.decimal,
      type_hash: type_hash,
      published: !!udt_info&.published,
      display_name: udt_info&.display_name,
      uan: udt_info&.uan
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
        value = { class_name: "", token_id: nil, total: "" }
      end
    else
      raise "invalid cell type"
    end
    CkbUtils.hash_value_to_s(value)
  end

  def nrc_721_nft_info
    return unless cell_type.in?(%w(nrc_721_token nrc_721_factory))

    case cell_type
    when "nrc_721_factory"
      factory_cell_type_script = self.type_script
      factory_cell = NrcFactoryCell.find_by(code_hash: factory_cell_type_script.code_hash, hash_type: factory_cell_type_script.hash_type, args: factory_cell_type_script.args, verified: true)
      value = { symbol: factory_cell&.symbol }
    when "nrc_721_token"
      udt = Udt.find_by(type_hash: type_hash)
      factory_cell = NrcFactoryCell.where(id: udt.nrc_factory_cell_id, verified: true).first
      value = { symbol: factory_cell&.symbol, amount: UdtAccount.where(udt_id: udt.id).first.nft_token_id }
    else
      raise "invalid cell type"
    end
    CkbUtils.hash_value_to_s(value)
  end

  def flush_cache
    $redis.pipelined do
      $redis.del(*cache_keys)
    end
  end

  def create_token
    case cell_type
    when "m_nft_class"
      parsed_class_data = CkbUtils.parse_token_class_data(data)
      TokenCollection.find_or_create_by(
        standard: "m_nft",
        name: parsed_class_data.name,
        cell_id: id,
        icon_url: parsed_class_data.renderer,
        creator_id: address.id
      )
    when "m_nft_token"
      m_nft_class_type = TypeScript.where(
        code_hash: CkbSync::Api.instance.token_class_script_code_hash,
        args: type_script.args[0..49]
      ).first
      if m_nft_class_type.present?
        m_nft_class_cell = m_nft_class_type.cell_outputs.last
        parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
        coll = TokenCollection.find_or_create_by(
          standard: "m_nft",
          name: parsed_class_data.name,
          cell_id: m_nft_class_cell.id,
          creator_id: m_nft_class_cell.address_id,
          icon_url: parsed_class_data.renderer
        )
        item = coll.items.find_or_create_by(
          token_id: type_script.args[50..-1].hex,
          owner_id: address_id,
          cell_id: id
        )
      end
    end
  end

  # Because the balance of address equals to the total capacity of all live cells in this address,
  # So we can directly aggregate balance by address from database.
  def self.refresh_address_balances
    puts "refreshing all balances"
    # fix balance and live cell count for all addresses
    connection.execute <<-SQL
    UPDATE addresses SET balance=sq.balance, live_cells_count=c
    FROM  (
      SELECT address_id, SUM(capacity) as balance, COUNT(*) as c
      FROM  cell_outputs
      WHERE status = 0
      GROUP  BY address_id
      ) AS sq
    WHERE  addresses.id=sq.address_id;
    SQL
    # fix occupied balances for all addresses
    puts "refreshing all occupied balances"
    connection.execute <<-SQL
    UPDATE addresses SET balance_occupied=sq.balance
    FROM  (
      SELECT address_id, SUM(capacity) as balance
      FROM  cell_outputs
      WHERE status = 0
            AND NOT ("cell_outputs"."type_hash" IS NULL AND "cell_outputs"."data" = '\x3078')
      GROUP  BY address_id
      ) AS sq
    WHERE  addresses.id=sq.address_id;
    SQL
    puts "refreshing dao deposits"
    connection.execute <<-SQL
    UPDATE addresses SET dao_deposit=sq.sum, is_depositor = sq.sum > 0
    FROM  (
      SELECT address_id, SUM(capacity) as sum
      FROM  cell_outputs
      WHERE status = 0
            AND cell_type = 1
      GROUP  BY address_id
      ) AS sq
    WHERE  addresses.id=sq.address_id;
    SQL
  end

  # update the history data, which cell_type should be "cota_registry" or "cota_regular"
  def self.update_cell_types_for_cota
    TypeScript.where(code_hash: CkbSync::Api.instance.cota_registry_code_hash).each do |type_script|
      CellOutput.where(type_script_id: type_script.id).each do |cell_output|
        cell_output.cell_type = "cota_registry"
        cell_output.save!
      end
    end

    TypeScript.where(code_hash: CkbSync::Api.instance.cota_regular_code_hash).each do |type_script|
      CellOutput.where(type_script_id: type_script.id).each do |cell_output|
        cell_output.cell_type = "cota_regular"
        cell_output.save!
      end
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
#  consumed_block_timestamp :decimal(30, )    default(0)
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
#  index_cell_outputs_on_type_script_id_and_id     (type_script_id,id)
#
