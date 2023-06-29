# A transaction in CKB is composed by several inputs and several outputs
# the inputs are the previous generated outputs
class CkbTransaction < ApplicationRecord
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
  has_many :account_books, dependent: :delete_all
  has_many :addresses, through: :account_books
  has_many :cell_inputs, dependent: :delete_all
  has_many :input_cells, through: :cell_inputs, source: :previous_cell_output
  has_many :cell_outputs, dependent: :delete_all
  accepts_nested_attributes_for :cell_outputs
  has_many :inputs, class_name: "CellOutput", inverse_of: "consumed_by", foreign_key: "consumed_by_id"
  has_many :outputs, class_name: "CellOutput"
  has_many :dao_events # , dependent: :delete_all
  has_many :script_transactions, dependent: :delete_all
  has_many :scripts, through: :script_transactions

  has_many :referring_cells, dependent: :delete_all
  has_many :token_transfers, foreign_key: :transaction_id, dependent: :delete_all, inverse_of: :ckb_transaction
  has_many :cell_dependencies, dependent: :delete_all
  has_many :header_dependencies, dependent: :delete_all
  has_many :witnesses, dependent: :delete_all

  has_one :reject_reason

  has_and_belongs_to_many :contained_addresses, class_name: "Address", join_table: "account_books"
  has_and_belongs_to_many :contained_udts, class_name: "Udt", join_table: :udt_transactions
  has_and_belongs_to_many :contained_dao_addresses, class_name: "Address", join_table: "address_dao_transactions"
  has_and_belongs_to_many :contained_udt_addresses, class_name: "Address", join_table: "address_udt_transactions"

  attribute :tx_hash, :ckb_hash

  scope :recent, -> { order("block_timestamp desc nulls last, id desc") }
  scope :cellbase, -> { where(is_cellbase: true) }
  scope :normal, -> { where(is_cellbase: false) }
  scope :created_after, ->(block_timestamp) { where("block_timestamp >= ?", block_timestamp) }
  scope :created_before, ->(block_timestamp) { where("block_timestamp <= ?", block_timestamp) }
  scope :created_between, ->(start_block_timestamp, end_block_timestamp) {
                            created_after(start_block_timestamp).created_before(end_block_timestamp)
                          }
  scope :inner_block, ->(block_id) { where("block_id = ?", block_id) }

  after_commit :flush_cache
  before_destroy :recover_dead_cell

  def self.cached_find(query_key)
    Rails.cache.realize([name, query_key], race_condition_ttl: 3.seconds) do
      find_by(tx_hash: query_key)
    end
  end

  def self.clean_pending
    tx_pending.find_each do |t|
      if where(tx_hash: t.tx_hash).where.not(tx_status: :pending).exists?
        t.destroy
      end
    end
  end

  def self.largest_in_epoch(epoch_number)
    Rails.cache.fetch(["epoch", epoch_number, "largest_tx"]) do
      tx = CkbTransaction.where(block: { epoch_number: epoch_number }).order(bytes: :desc).first
      if tx.bytes
        {
          tx_hash: tx.tx_hash,
          bytes: tx.bytes
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
    cell_dependencies.explicit.includes(:cell_output).to_a.map(&:to_raw)
  end

  def display_inputs(previews: false)
    if is_cellbase
      cellbase_display_inputs
    else
      normal_tx_display_inputs(previews)
    end
  end

  def display_outputs(previews: false)
    if is_cellbase
      cellbase_display_outputs
    else
      normal_tx_display_outputs(previews)
    end
  end

  def income(address)
    outputs.where(address: address).sum(:capacity) - inputs.where(address: address).sum(:capacity)
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

  def cell_info
    nil
  end

  def detailed_message
    reject_reason&.message
  end

  # convert current record to raw hash with standard RPC json data structure
  def to_raw
    Rails.cache.fetch([self.class.name, tx_hash, "raw_hash"], expires_in: 1.day) do
      _outputs = cell_outputs.order(cell_index: :asc).to_a
      cell_deps = cell_dependencies.explicit.includes(:cell_output).to_a

      {
        hash: tx_hash,
        header_deps: header_dependencies.map(&:header_hash),
        cell_deps: cell_deps.map(&:to_raw),
        inputs: cell_inputs.map(&:to_raw),
        outputs: _outputs.map(&:to_raw),
        outputs_data: _outputs.map(&:data),
        version: "0x#{version.to_s(16)}",
        witnesses: witnesses.map(&:data)
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
      map { |date, fee_rate| { date: Time.at(date * 86400).utc.strftime("%Y-%m-%d"), fee_rate: fee_rate } }
  end

  private

  def normal_tx_display_outputs(previews)
    cell_outputs_for_display = outputs.sort_by(&:id)
    if previews
      cell_outputs_for_display = cell_outputs_for_display[0, 10]
    end
    cell_outputs_for_display.map do |output|
      consumed_tx_hash = output.live? ? nil : output.consumed_by&.tx_hash
      display_output = {
        id: output.id,
        capacity: output.capacity,
        address_hash: output.address_hash,
        status: output.status,
        consumed_tx_hash: consumed_tx_hash,
        cell_type: output.cell_type
      }
      display_output.merge!(attributes_for_udt_cell(output)) if output.udt?
      display_output.merge!(attributes_for_cota_registry_cell(output)) if output.cota_registry?
      display_output.merge!(attributes_for_cota_regular_cell(output)) if output.cota_regular?

      display_output.merge!(attributes_for_m_nft_cell(output)) if output.cell_type.in?(%w(
                                                                                         m_nft_issuer m_nft_class
                                                                                         m_nft_token
                                                                                       ))
      display_output.merge!(attributes_for_nrc_721_cell(output)) if output.cell_type.in?(%w(
                                                                                           nrc_721_token
                                                                                           nrc_721_factory
                                                                                         ))

      CkbUtils.hash_value_to_s(display_output)
    end
  end

  def cellbase_display_outputs
    cell_outputs_for_display = outputs.to_a.sort_by(&:id)
    cellbase = Cellbase.new(block)
    cell_outputs_for_display.map do |output|
      consumed_tx_hash = output.live? ? nil : output.consumed_by.tx_hash
      CkbUtils.hash_value_to_s(id: output.id, capacity: output.capacity, address_hash: output.address_hash,
                               target_block_number: cellbase.target_block_number, base_reward: cellbase.base_reward, commit_reward: cellbase.commit_reward, proposal_reward: cellbase.proposal_reward, secondary_reward: cellbase.secondary_reward, status: output.status, consumed_tx_hash: consumed_tx_hash)
    end
  end

  def normal_tx_display_inputs(previews)
    cell_inputs_for_display = cell_inputs.to_a.sort_by(&:id)
    if previews
      cell_inputs_for_display = cell_inputs_for_display[0, 10]
    end
    cell_inputs_for_display.each_with_index.map do |cell_input, index|
      previous_cell_output = cell_input.previous_cell_output
      unless previous_cell_output
        next({
          from_cellbase: false,
          capacity: "",
          address_hash: "",
          generated_tx_hash: cell_input.previous_tx_hash,
          cell_index: cell_input.previous_index,
          since: {
            raw: hex_since(cell_input.since.to_i),
            median_timestamp: cell_input.block&.median_timestamp.to_i
          }
        })
      end

      display_input = {
        id: previous_cell_output.id,
        from_cellbase: false,
        capacity: previous_cell_output.capacity,
        address_hash: previous_cell_output.address_hash,
        generated_tx_hash: previous_cell_output.ckb_transaction.tx_hash,
        cell_index: previous_cell_output.cell_index,
        cell_type: previous_cell_output.cell_type,
        since: {
          raw: hex_since(cell_input.since.to_i),
          median_timestamp: cell_input.block&.median_timestamp.to_i
        }
      }
      display_input.merge!(attributes_for_dao_input(previous_cell_output)) if previous_cell_output.nervos_dao_withdrawing?
      if previous_cell_output.nervos_dao_deposit?
        display_input.merge!(attributes_for_dao_input(cell_outputs[index],
                                                      false))
      end
      display_input.merge!(attributes_for_udt_cell(previous_cell_output)) if previous_cell_output.udt?
      display_input.merge!(attributes_for_m_nft_cell(previous_cell_output)) if previous_cell_output.cell_type.in?(%w(
                                                                                                                    m_nft_issuer m_nft_class m_nft_token
                                                                                                                  ))
      display_input.merge!(attributes_for_nrc_721_cell(previous_cell_output)) if previous_cell_output.cell_type.in?(%w(
                                                                                                                      nrc_721_token nrc_721_factory
                                                                                                                    ))

      CkbUtils.hash_value_to_s(display_input)
    end
  end

  def hex_since(int_since_value)
    return "0x#{int_since_value.to_s(16).rjust(16, '0')}"
  end

  def attributes_for_udt_cell(udt_cell)
    info = CkbUtils.hash_value_to_s(udt_cell.udt_info)
    {
      udt_info: info,
      extra_info: info
    }
  end

  def attributes_for_m_nft_cell(m_nft_cell)
    info = m_nft_cell.m_nft_info
    { m_nft_info: info, extra_info: info }
  end

  def attributes_for_cota_registry_cell(cota_cell)
    info = cota_cell.cota_registry_info
    { cota_registry_info: info, extra_info: info }
  end

  def attributes_for_cota_regular_cell(cota_cell)
    info = cota_cell.cota_regular_info
    { cota_regular_info: info, extra_info: info }
  end

  def attributes_for_nrc_721_cell(nrc_721_cell)
    info = nrc_721_cell.nrc_721_nft_info
    { nrc_721_token_info: info, extra_info: info }
  end

  def attributes_for_dao_input(nervos_dao_withdrawing_cell, is_phase2 = true)
    nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.ckb_transaction
    nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
    # start block: the block contains the trasaction which generated the deposit cell output
    compensation_started_block = Block.select(:number, :timestamp).find(nervos_dao_deposit_cell.block.id)
    # end block: the block contains the transaction which generated the withdrawing cell
    compensation_ended_block = Block.select(:number, :timestamp).find(nervos_dao_withdrawing_cell_generated_tx.block_id)
    interest = CkbUtils.dao_interest(nervos_dao_withdrawing_cell)

    attributes = {
      compensation_started_block_number: compensation_started_block.number,
      compensation_started_timestamp: compensation_started_block.timestamp,
      compensation_ended_block_number: compensation_ended_block.number,
      compensation_ended_timestamp: compensation_ended_block.timestamp,
      interest: interest
    }

    if is_phase2
      number, timestamp = Block.where(id: block_id).pick(:number, :timestamp) # locked_until_block
      attributes[:locked_until_block_number] = number
      attributes[:locked_until_block_timestamp] = timestamp
    end

    CkbUtils.hash_value_to_s(attributes)
  end

  def cellbase_display_inputs
    cellbase = Cellbase.new(block)
    [
      CkbUtils.hash_value_to_s(
        id: nil,
        from_cellbase: true,
        capacity: nil,
        address_hash: nil,
        target_block_number: cellbase.target_block_number,
        generated_tx_hash: tx_hash
      )
    ]
  end

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
#  confirmation_time :integer
#
# Indexes
#
#  ckb_tx_uni_tx_hash                 (tx_status,tx_hash) UNIQUE
#  idx_ckb_txs_for_blocks             (block_id,block_timestamp)
#  idx_ckb_txs_timestamp              (block_timestamp DESC NULLS LAST,id)
#  index_ckb_transactions_on_tags     (tags) USING gin
#  index_ckb_transactions_on_tx_hash  (tx_hash) USING hash
#
