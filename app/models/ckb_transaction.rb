# A transaction in CKB is composed by several inputs and several outputs
# the inputs are the previous generated outputs
class CkbTransaction < ApplicationRecord
  include CkbTransactions::DisplayCells
  include CkbTransactions::Bitcoin

  self.primary_key = :id
  MAX_PAGINATES_PER = 100
  DEFAULT_PAGINATES_PER = 10
  paginates_per DEFAULT_PAGINATES_PER
  max_paginates_per MAX_PAGINATES_PER

  enum tx_status: { pending: 0, proposed: 1, committed: 2, rejected: 3 }, _prefix: :tx
  belongs_to :block, optional: true # when a transaction is pending, it does not belongs to any block
  has_many :block_transactions
  has_many :included_blocks, class_name: "Block",
                             through: :block_transactions,
                             inverse_of: :contained_transactions
  has_many :account_books
  has_many :addresses, through: :account_books
  has_many :cell_inputs
  has_many :input_cells, through: :cell_inputs, source: :previous_cell_output
  has_many :cell_outputs
  accepts_nested_attributes_for :cell_outputs
  has_many :inputs, class_name: "CellOutput", inverse_of: "consumed_by", foreign_key: "consumed_by_id"
  has_many :outputs, class_name: "CellOutput"
  has_many :dao_events
  has_many :contained_dao_addresses, -> { distinct }, through: :dao_events, source: :address

  has_many :token_transfers, foreign_key: :transaction_id, inverse_of: :ckb_transaction
  has_many :cell_dependencies
  has_many :header_dependencies
  has_many :witnesses

  has_one :reject_reason

  has_and_belongs_to_many :contained_addresses, class_name: "Address", join_table: "account_books"
  has_and_belongs_to_many :contained_udts, class_name: "Udt", join_table: :udt_transactions
  has_and_belongs_to_many :contained_udt_addresses, class_name: "Address", join_table: "address_udt_transactions"

  attribute :tx_hash, :ckb_hash

  scope :recent, -> { order("ckb_transactions.block_timestamp desc nulls last, ckb_transactions.tx_index desc") }
  scope :cellbase, -> { where(is_cellbase: true) }
  scope :normal, -> { where(is_cellbase: false) }
  scope :created_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :created_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }
  scope :created_between, ->(start_block_timestamp, end_block_timestamp) {
                            created_after(start_block_timestamp).created_before(end_block_timestamp)
                          }
  scope :inner_block, ->(block_id) { where("block_id = ?", block_id) }
  scope :h24, -> { where("block_timestamp >= ?", 24.hours.ago.to_i * 1000) }

  after_commit :flush_cache
  before_destroy :recover_dead_cell

  def self.cached_find(query_key)
    Rails.cache.realize([name, query_key], race_condition_ttl: 3.seconds) do
      find_by(tx_hash: query_key)
    end
  end

  def self.largest_in_epoch(epoch_number)
    Rails.cache.fetch(["epoch", epoch_number, "largest_tx"]) do
      tx = CkbTransaction.where(block: { epoch_number: }).order(bytes: :desc).first
      if tx.bytes
        {
          tx_hash: tx.tx_hash,
          bytes: tx.bytes,
        }
      end
    end
  end

  # save raw hash to cache
  # @param tx_hash [String , Hash]
  # @param raw_hash [Hash , nil]
  def self.write_raw_hash_cache(tx_hash, raw_hash = nil)
    unless raw_hash
      raw_hash = tx_hash
      tx_hash = raw_hash["hash"]
    end
    Rails.cache.write([name, tx_hash, "raw_hash"], raw_hash, expires_in: 1.day)
  end

  # fetch using rpc method "get_transaction"
  # See https://github.com/nervosnetwork/ckb/blob/master/rpc/README.md#method-get_transaction
  # @param tx_hash [String]
  # @param write_raw_hash_cache [Boolean] if we should write raw hash of transaction without status to cache
  # @return [Hash]
  def self.fetch_raw_hash_with_status(tx_hash, write_raw_hash_cache: true)
    Rails.cache.fetch([name, tx_hash, "raw_hash_with_status"], expires_in: 1.day, skip_nil: true) do
      res = CkbSync::Api.instance.directly_single_call_rpc method: "get_transaction", params: [tx_hash]
      h = res["result"].with_indifferent_access
      self.write_raw_hash_cache(tx_hash, h["transaction"]) if write_raw_hash_cache
      h
    end
  end

  # fetching raw hash
  # See https://github.com/nervosnetwork/ckb/blob/master/rpc/README.md#method-get_transaction
  # @param tx_hash [String]
  # @return [Hash]
  def self.fetch_raw_hash(tx_hash)
    Rails.cache.fetch([name, tx_hash, "raw_hash"], expires_in: 1.day, skip_nil: true) do
      fetch_raw_hash_with_status(tx_hash, write_raw_hash_cache: false)["transaction"]
    end
  end

  # fetching the transaction object with status generated by ckb ruby sdk
  # @param tx_hash [String]
  # @return [CKB::Types::TransactionWithStatus]
  def self.fetch_sdk_transaction_with_status(tx_hash, write_object_cache: true)
    Rails.cache.fetch([name, tx_hash, "object_with_status"], expires_in: 1.day, skip_nil: true) do
      tx = CKB::Types::TransactionWithStatus.from_h fetch_raw_hash_with_status(tx_hash)
      Rails.cache.write([name, tx_hash, "object"], tx.transaction, expires_in: 1.day) if write_object_cache
      tx
    end
  end

  # fetch the transaction object without status generated by ckb ruby sdk
  # @param tx_hash [String]
  # @return [CKB::Types::Transaction]
  def self.fetch_sdk_transaction(tx_hash)
    Rails.cache.fetch([name, tx_hash, "object"], expires_in: 1.day, skip_nil: true) do
      sdk_tx_with_status = Rails.cache.read([name, tx_hash, "object_with_status"])
      if sdk_tx_with_status
        return sdk_transaction_with_status.transaction
      else
        tx = CKB::Types::Transaction.from_h fetch_raw_hash(tx_hash).with_indifferent_access
        Rails.cache.write([name, tx_hash, "object"], tx, expires_in: 1.day)
        tx
      end
    end
  end

  # return the original json data fetched from ckb node, with status of current transaction
  # @return [Hash]
  def raw_hash_with_status
    @raw_hash_with_status ||=
      begin
        h = self.class.fetch_raw_hash_with_status(tx_hash)
        @raw_hash = h["transaction"] # directly set related transaction hash
        h
      end
  end

  # return the structured transaction object of current CkbTransaction for use with CKB SDK
  # @return [CKB::Types::TransactionWithStatus]
  def sdk_transaction_with_status
    @sdk_transaction_with_status ||=
      begin
        tx = self.class.fetch_sdk_transaction_with_status(tx_hash)
        @sdk_transaction = tx.transaction
        tx
      end
  end

  # return the original json data fetched from ckb node, without status
  # the websocket client will directly write the raw hash(without tx_status) to cache
  # @return [Hash]
  def raw_hash
    @raw_hash ||= self.class.fetch_raw_hash(tx_hash)
  end

  # return the structured transaction object of current CkbTransaction for use with CKB SDK
  # @return [CKB::Types::Transaction]
  def sdk_transaction
    @sdk_transaction ||= sdk_transaction_with_status.transaction
  end

  def reset_cycles
    block.get_block_cycles
  end

  def flush_cache
    Rails.cache.delete([self.class.name, tx_hash])
  end

  def header_deps
    header_dependencies.map(&:header_hash)
  end

  def cell_deps
    _outputs = cell_outputs.order(cell_index: :asc).to_a
    cell_dependencies.includes(:cell_output).to_a.map(&:to_raw)
  end

  def income(address)
    if tx_pending?
      cell_outputs.where(address:).sum(:capacity) - input_cells.where(address:).sum(:capacity)
    else
      outputs.where(address:).sum(:capacity) - inputs.where(address:).sum(:capacity)
    end
  end

  def dao_transaction?
    inputs.where(cell_type: %w(
                   nervos_dao_deposit
                   nervos_dao_withdrawing
                 )).exists? || outputs.where(cell_type: %w(
                                               nervos_dao_deposit
                                               nervos_dao_withdrawing
                                             )).exists?
  end

  def detailed_message
    reject_reason&.message
  end

  # convert current record to raw hash with standard RPC json data structure
  def to_raw
    Rails.cache.fetch([self.class.name, tx_hash, "raw_hash"], expires_in: 1.day) do
      _outputs = cell_outputs.order(cell_index: :asc).to_a
      cell_deps = cell_dependencies.includes(:cell_output).to_a

      {
        hash: tx_hash,
        header_deps: header_dependencies.map(&:header_hash),
        cell_deps: cell_deps.map(&:to_raw),
        inputs: cell_inputs.map(&:to_raw),
        outputs: _outputs.map(&:to_raw),
        outputs_data: _outputs.map(&:data),
        version: "0x#{version.to_s(16)}",
        witnesses: witnesses.map(&:data),
      }
    end
  end

  def self.last_n_days_transaction_fee_rates(last_n_day)
    CkbTransaction.
      where("bytes > 0 and transaction_fee > 0").
      where("block_timestamp >= ?", last_n_day.days.ago.to_i * 1000).
      group("(block_timestamp / 86400000)::integer").
      pluck(Arel.sql("(block_timestamp / 86400000)::integer as date"),
            Arel.sql("sum(transaction_fee / bytes) / count(*) as fee_rate")).
      map { |date, fee_rate| { date: Time.at(date * 86400).utc.strftime("%Y-%m-%d"), fee_rate: } }
  end

  private

  def recover_dead_cell
    inputs.update_all(status: "live", consumed_by_id: nil, consumed_block_timestamp: nil)
  end
end

# == Schema Information
#
# Table name: ckb_transactions
#
#  id                :bigint           not null, primary key
#  tx_hash           :binary
#  block_id          :bigint
#  block_number      :bigint
#  block_timestamp   :bigint
#  tx_status         :integer          default("committed"), not null
#  version           :integer          default(0), not null
#  is_cellbase       :boolean          default(FALSE)
#  transaction_fee   :bigint
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  live_cell_changes :integer
#  capacity_involved :decimal(30, )
#  tags              :string           default([]), is an Array
#  bytes             :bigint           default(0)
#  cycles            :bigint
#  confirmation_time :bigint
#  tx_index          :integer
#
# Indexes
#
#  ckb_tx_uni_tx_hash                 (tx_status,tx_hash) UNIQUE
#  idx_ckb_txs_for_blocks             (block_id,block_timestamp)
#  idx_ckb_txs_timestamp              (block_timestamp DESC NULLS LAST,id)
#  index_ckb_transactions_on_tags     (tags) USING gin
#  index_ckb_transactions_on_tx_hash  (tx_hash) USING hash
#
