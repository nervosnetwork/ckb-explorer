class CellOutput < ApplicationRecord
  include CellOutputs::ExtraInfo

  self.primary_key = :id

  SYSTEM_TX_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000".freeze
  MAXIMUM_DOWNLOADABLE_SIZE = 64000
  MIN_SUDT_AMOUNT_BYTESIZE = 16
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  enum status: { live: 0, dead: 1, pending: 2, rejected: 3 }
  enum cell_type: {
    normal: 0,
    nervos_dao_deposit: 1,
    nervos_dao_withdrawing: 2,
    udt: 3,
    m_nft_issuer: 4,
    m_nft_class: 5,
    m_nft_token: 6,
    nrc_721_token: 7,
    nrc_721_factory: 8,
    cota_registry: 9,
    cota_regular: 10,
    spore_cluster: 11,
    spore_cell: 12,
    omiga_inscription_info: 13,
    omiga_inscription: 14,
    xudt: 15,
    unique_cell: 16,
    xudt_compatible: 17,
    did_cell: 18,
  }

  belongs_to :ckb_transaction
  # the consumed_by_id will be set only when transaction is committed on chain
  belongs_to :consumed_by, class_name: "CkbTransaction", optional: true
  # the inputs which consumes this cell output
  # but one cell may be included by many pending transactions,
  # the cell_inputs won't always be the same as `consumed_by`.`cell_inputs`
  has_many :cell_inputs, foreign_key: :previous_cell_output_id
  belongs_to :deployed_cell, optional: true
  has_many :referring_cells
  # the block_id is actually the same as ckb_transaction.block_id, must be on chain
  # but one cell may be included by pending transactions, so block_id may be null
  belongs_to :block, optional: true
  belongs_to :address
  belongs_to :lock_script
  belongs_to :type_script, optional: true

  has_many :cell_dependencies, foreign_key: :contract_cell_id,
                               dependent: :delete_all
  has_one :cell_datum, class_name: "CellDatum", dependent: :destroy_async
  has_one :bitcoin_vout
  has_one :bitcoin_transfer

  accepts_nested_attributes_for :cell_datum
  validates :capacity, presence: true,
                       numericality: { greater_than_or_equal_to: 0 }

  # on-chain cell outputs must be included in certain block
  validates :block, presence: true, if: -> { live? or dead? }

  # cell output must not have this field set when they are not on-chain
  validates :block_id, must_be_nil: true, if: -> { pending? or rejected? }

  # cell output must have corresponding consuming transaction if it is dead
  validates :consumed_by, presence: true, if: :dead?

  # cell output must not have consumed_by_id set when it's live
  validates :consumed_by_id, :consumed_block_timestamp, must_be_nil: true,
                                                        if: :live?

  # consumed timestamp must be always greater than committed timestamp
  validates :consumed_block_timestamp, numericality: { greater_than_or_equal_to: :block_timestamp },
                                       if: :consumed_block_timestamp?

  attribute :tx_hash, :ckb_hash

  attr_accessor :raw_address

  scope :consumed_after, ->(block_timestamp) {
                           where("consumed_block_timestamp >= ?", block_timestamp)
                         }
  scope :consumed_before, ->(block_timestamp) {
                            where("consumed_block_timestamp <= ?", block_timestamp)
                          }
  scope :consumed_between, ->(start_timestamp, end_timestamp) {
                             consumed_after(start_timestamp).consumed_before(end_timestamp)
                           }
  scope :unconsumed_at, ->(block_timestamp) {
                          where("consumed_block_timestamp > ? or consumed_block_timestamp = 0 or consumed_block_timestamp is null", block_timestamp)
                        }
  scope :generated_after, ->(block_timestamp) {
                            where("block_timestamp >= ?", block_timestamp)
                          }
  scope :generated_before, ->(block_timestamp) {
                             where("block_timestamp <= ?", block_timestamp)
                           }
  scope :generated_between, ->(start_timestamp, end_timestamp) {
                              generated_after(start_timestamp).generated_before(end_timestamp)
                            }
  scope :inner_block, ->(block_id) { where("block_id = ?", block_id) }
  scope :free, -> { where(type_hash: nil, data_hash: nil) }
  scope :occupied, -> {
                     where.not(type_hash: nil).or(where.not(data_hash: nil))
                   }

  before_create :setup_address

  def data=(new_data)
    @data = new_data
    if new_data
      d = CKB::Utils.hex_to_bin(new_data)
      if d.size > 0
        datum = cell_datum || build_cell_datum
        datum.data = d
        datum.save
      end
    elsif cell_datum
      cell_datum.destroy
    end
  end

  def data
    @data ||= CKB::Utils.bin_to_hex(cell_datum&.data || "")
  end

  def binary_data
    cell_datum&.data
  end

  def setup_address
    if raw_address
      self.address = Address.find_or_create_by_address_hash(raw_address,
                                                            block_timestamp)
    end
  end

  # @return [Boolean]
  def occupied?
    !free?
  end

  # @return [Boolean]
  def free?
    type_hash.blank? && (data.present? && data == "0x")
  end

  def address_hash
    address.address_hash
  end

  def dao
    self[:dao] || block.dao
  end

  # find cell output according to the out point( tx_hash and output index )
  # @param [String] tx_hash
  # @param [Integer] index
  # @return [CellOutput]
  def self.find_by_pointer(tx_hash, index)
    Rails.cache.fetch(["cell_output", tx_hash, index], skip_nil: true,
                                                       race_condition_ttl: 10.seconds,
                                                       expires_in: 1.day) do
      tx_id = CkbTransaction.tx_committed.find_by_tx_hash(tx_hash)&.id
      Rails.logger.info("find_by_pointer: tx_hash: #{tx_hash}, index: #{index}, tx_id: #{tx_id}")
      if tx_id
        find_by(ckb_transaction_id: tx_id,
                cell_index: index.is_a?(String) ? index.hex : index)
      end
    end
  end

  def node_output
    lock = CKB::Types::Script.new(**lock_script.to_node)
    type = type_script.present? ? CKB::Types::Script.new(**type_script.to_node) : nil
    CKB::Types::Output.new(capacity: capacity.to_i, lock:, type:)
  end

  # calculate the actual size of the cell output on chain
  # @return [Integer]
  def calculate_bytesize
    [8, binary_data&.bytesize || 0, lock_script.calculate_bytesize,
     type_script&.calculate_bytesize || 0].sum
  end

  def calculate_min_capacity
    CKB::Utils.byte_to_shannon(calculate_bytesize)
  end

  def to_raw
    {
      capacity: "0x#{capacity.to_i.to_s(16)}",
      lock: lock_script&.to_node,
      type: type_script&.to_node,
    }
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
        creator_id: address.id,
      )
    when "m_nft_token"
      m_nft_class_type = TypeScript.where(
        code_hash: CkbSync::Api.instance.token_class_script_code_hash,
        args: type_script.args[0..49],
      ).first
      if m_nft_class_type.present?
        m_nft_class_cell = m_nft_class_type.cell_outputs.last
        parsed_class_data = CkbUtils.parse_token_class_data(m_nft_class_cell.data)
        coll = TokenCollection.find_or_create_by(
          standard: "m_nft",
          name: parsed_class_data.name,
          cell_id: m_nft_class_cell.id,
          creator_id: m_nft_class_cell.address_id,
          icon_url: parsed_class_data.renderer,
        )
        item = coll.items.find_or_create_by(
          token_id: type_script.args[50..-1].hex,
          owner_id: address_id,
          cell_id: id,
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
            AND "cell_outputs"."type_hash" IS NOT NULL AND "cell_outputs"."data" != '\x3078'
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

  def self.dead_reltuples_count
    sql = "SELECT reltuples FROM pg_class WHERE relname = 'cell_outputs_dead'"
    result = ActiveRecord::Base.connection.execute(sql)
    result.getvalue(0, 0).to_i
  end
end

# == Schema Information
#
# Table name: cell_outputs
#
#  id                       :bigint           not null, primary key
#  capacity                 :decimal(64, 2)
#  ckb_transaction_id       :bigint
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  status                   :integer          default("live"), not null
#  address_id               :decimal(30, )
#  block_id                 :decimal(30, )
#  tx_hash                  :binary
#  cell_index               :integer
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
#  data_hash                :binary
#
# Indexes
#
#  index_cell_outputs_on_address_id                         (address_id)
#  index_cell_outputs_on_block_id                           (block_id)
#  index_cell_outputs_on_block_timestamp                    (block_timestamp)
#  index_cell_outputs_on_consumed_block_timestamp           (consumed_block_timestamp)
#  index_cell_outputs_on_consumed_by_id                     (consumed_by_id)
#  index_cell_outputs_on_lock_script_id                     (lock_script_id)
#  index_cell_outputs_on_tx_hash_and_cell_index_and_status  (tx_hash,cell_index,status) UNIQUE
#  index_cell_outputs_on_tx_id_and_cell_index_and_status    (ckb_transaction_id,cell_index,status) UNIQUE
#  index_cell_outputs_on_type_script_id                     (type_script_id)
#
