require "date"

# standards for a block on chain
# block will contain many transactions
# the first transaction is always a cellbase transaction
# which give rewards to miner
# different blocks committed by different miners may pack the same transactions
# we use block_transactions intermediate table to associate block and transaction
# when the block is confirmed by chain, we use the block_id in ckb_transactions to
# reference the block
class Block < ApplicationRecord
  MAX_PAGINATES_PER = 100
  paginates_per 10
  max_paginates_per MAX_PAGINATES_PER

  enum reward_status: { pending: 0, issued: 1 }
  enum target_block_reward_status: { pending: 0, issued: 1 }, _prefix: :target_block
  enum received_tx_fee_status: { pending: 0, calculated: 1 }, _prefix: :current_block

  # the `ckb_transactions` is only available when the block is included in chain
  has_many :ckb_transactions
  has_many :block_transactions
  # the transactions included in the block no matter if the block is included in chain
  has_many :contained_transactions, class_name: "CkbTransaction",
                                    through: :block_transactions,
                                    inverse_of: :included_blocks
  has_many :uncle_blocks
  has_many :cell_outputs
  has_many :cell_inputs
  has_many :dao_events
  has_many :mining_infos
  belongs_to :parent_block, class_name: "Block", foreign_key: "parent_hash", primary_key: "block_hash", optional: true,
                            inverse_of: :subsequent_blocks

  # one block can have serveral different subsequent blocks, and only one can be included on chain
  has_many :subsequent_blocks, class_name: "Block", foreign_key: "parent_hash", primary_key: "block_hash",
                               inverse_of: :parent_block
  belongs_to :epoch_statistic, primary_key: :epoch_number, foreign_key: :epoch, optional: true

  validates_presence_of :block_hash, :number, :parent_hash, :timestamp, :transactions_root, :proposals_hash,
                        :uncles_count, :extra_hash, :version, :cell_consumed, :reward, :total_transaction_fee,
                        :ckb_transactions_count, :total_cell_capacity, on: :create
  validates :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, :cell_consumed,
            numericality: { greater_than_or_equal_to: 0 }

  attribute :block_hash, :ckb_hash
  attribute :parent_hash, :ckb_hash
  attribute :transactions_root, :ckb_hash
  attribute :proposals_hash, :ckb_hash
  attribute :extra_hash, :ckb_hash
  attribute :uncle_block_hashes, :ckb_array_hash, hash_length: Settings.default_hash_length
  attribute :proposals, :ckb_array_hash, hash_length: Settings.default_short_hash_length

  scope :recent, -> { order("timestamp desc nulls last") }
  scope :created_after, ->(timestamp) { where("timestamp >= ?", timestamp) }
  scope :created_before, ->(timestamp) { where("timestamp <= ?", timestamp) }
  scope :created_between, ->(from, to) { where(timestamp: from..to) }
  scope :h24, -> { where("timestamp > ?", 24.hours.ago.to_datetime.strftime("%Q")) }

  def self.tip_block
    recent.first
  end

  after_commit :flush_cache

  def self.query_transaction_fee_rate(date_string)
    date = DateTime.strptime date_string, "%Y-%m-%d"
    sql = <<-SQL
      select date_trunc('day', to_timestamp(timestamp/1000.0)) date,
        avg(total_transaction_fee / ckb_transactions_count ) fee_rate
      from blocks
      where timestamp >= #{date.beginning_of_day.to_i * 1000}
        and timestamp <= #{date.end_of_day.to_i * 1000}
        and ckb_transactions_count != 0
      group by date order by date desc
    SQL

    # [[2022-02-10 00:00:00 +0000, 0.585996275650410425301290958e7]]
    connection.select_value(sql)
  end

  def self.fetch_transaction_fee_rate_from_cache(date_string)
    Rails.cache.fetch("transaction_fee_rate_#{date_string}", expires_in: 10.minutes) do
      self.query_transaction_fee_rate date_string
    end
  end

  def self.last_7_days_ckb_node_version
    from = 7.days.ago.to_i * 1000
    sql = "select ckb_node_version, count(*) from blocks where timestamp >= #{from} group by ckb_node_version order by 1 asc;"
    connection.execute(sql).values
  end

  # fetch block hash from cache
  # because the chain may reorg sometimes
  # so we can only store cache against block hash
  # See https://github.com/nervosnetwork/ckb/blob/master/rpc/README.md#method-get_block
  # @param block_hash [String] block hash
  # @return [Hash] raw hash of the block
  def self.fetch_raw_hash_with_cycles(block_hash)
    Rails.cache.fetch(["Block", block_hash, "raw_hash_with_cycles"], expires_in: 1.day) do
      res = CkbSync::Api.instance.directly_single_call_rpc method: "get_block", params: [block_hash, "0x2", true]

      r = res["result"].with_indifferent_access

      # store transaction hash directly to cache ahead
      r["block"]["transactions"].each do |tx|
        CkbTransaction.write_raw_hash_cache tx["hash"], tx
      end
      r
    end
  end

  # fetch block hash from cache without cycles information
  # See https://github.com/nervosnetwork/ckb/blob/master/rpc/README.md#method-get_block
  # @param block_hash [String] block hash
  # @return [Hash] raw hash of the block
  def self.fetch_raw_hash(block_hash)
    fetch_raw_hash_with_cycles(block_hash)[:block]
  end

  # fetch raw hash from chain with cycles information
  # because the chain may reorg sometimes
  # so we cannot store cache against block number
  # @param number [Integer] block number
  # @return [Hash] raw hash with cycles of the block
  def self.fetch_raw_hash_with_cycles_by_number(number)
    res = CkbSync::Api.instance.directly_single_call_rpc method: "get_block_by_number",
                                                         params: [
                                                           "0x#{number.to_s(16)}", "0x2", true
                                                         ]
    if res["error"]
      raise res["error"]["message"]
    end

    r = res["result"].with_indifferent_access
    # because the chain may reorg sometimes
    # so we can only store cache against block hash
    Rails.cache.write(["Block", r["block"]["header"]["hash"], "raw_hash"], r["block"], expires_in: 1.day)
    # store transaction hash directly to cache ahead
    r["block"]["transactions"].each do |tx|
      CkbTransaction.write_raw_hash_cache tx["hash"], tx
    end

    r
  end

  # fetch block information by block number without cycles information
  # @param number [Integer] block number
  # @return [Hash] raw hash of the block
  def self.fetch_raw_hash_by_number(number)
    fetch_raw_hash_with_cycles_by_number(number)[:block]
  end

  # fetch block information by block number with cycles information of current block object
  # @return [Hash] raw hash of the block
  def raw_hash_with_cycles
    @raw_hash_with_cycles ||= self.class.fetch_raw_hash_with_cycles block_hash
  end

  # fetch block information by block number without cycles information of current block object
  # @return [Hash] raw hash of the block
  def raw_hash
    @raw_hash ||= raw_hash_with_cycles[:block]
  end

  # the block object generated by ruby sdk
  # @return [CKB::Types::Block]
  def sdk_block
    @sdk_block ||=
      Rails.cache.fetch(["Block", block_hash, "object"], expires_in: 1.hour) do
        CKB::Types::Block.from_h(original_raw_hash)
      end
  end

  def get_block_cycles
    @block_cycles ||= original_raw_hash_with_cycles[:cycles]
  end

  def reset_cycles
    i = 0
    cycles = 0
    ckb_transactions.find_each do |transaction|
      if i > 0
        c = get_block_cycles[i - 1]
        if c
          transaction.cycles = c.hex
          cycles += transaction.cycles
          transaction.save
        end
      end
      i += 1
    end
    self.cycles = cycles # ckb_transactions.sum(:cycles)
  end

  def reset_block_size
    self.block_size = raw_block.serialized_size_without_uncle_proposals
  end

  def contained_addresses
    Address.where(id: address_ids)
  end

  def cellbase
    ckb_transactions.cellbase.first
  end

  def target_block_number
    number - (Settings.proposal_window || 10).to_i - 1
  end

  def genesis_block?
    number.zero?
  end

  def target_block
    @target_block ||= Block.find_by(number: target_block_number)
  end

  def difficulty
    CkbUtils.compact_to_difficulty(compact_target)
  end

  def block_index_in_epoch
    number - start_number
  end

  def fraction_epoch
    OpenStruct.new(number: epoch, index: block_index_in_epoch, length: length)
  end

  def self.find_block!(query_key)
    cached_find(query_key) || raise(Api::V1::Exceptions::BlockNotFoundError)
  end

  def self.cached_find(query_key)
    Rails.cache.fetch([name, query_key], race_condition_ttl: 3.seconds) do
      if QueryKeyUtils.valid_hex?(query_key)
        block = where(block_hash: query_key).first
      else
        block = where(number: query_key).first
      end
      BlockSerializer.new(block) if block.present?
    end
  end

  #
  # @param epoch_number [Integer]
  # @return [Hash] {number: block_number, bytes: block_size}
  def self.largest_in_epoch(epoch_number)
    Rails.cache.fetch([:epoch, epoch_number, :largest_block]) do
      b = Block.where(epoch: epoch_number).order(block_size: :desc).first
      if b&.block_size
        {
          number: b.number,
          bytes: b.block_size
        }
      end
    end
  end

  def miner_address
    Address.find_by_address_hash(miner_hash)
  end

  def flush_cache
    $redis.pipelined do
      Rails.cache.delete_multi(cache_keys)
    end
  end

  def cache_keys
    %W(#{self.class.name}/#{block_hash} #{self.class.name}/#{number})
  end

  def invalid!
    uncle_blocks.delete_all
    # delete_address_txs_cache
    ckb_transactions.destroy_all
    ForkedBlock.create(attributes)
    destroy
  end

  # update existing block data. to update its median_timestamp
  # only run once.
  # usage:
  # 1. bundle exec rails console
  # 2. Block.update_block_median_timestamp <block_number>
  # @param block_number [Integer] the block number to start update
  def self.update_block_median_timestamp(block_number)
    Block.where("id < ?", block_number).find_in_batches(batch_size: 2000) do |blocks|
      single_payload = []
      blocks.each do |block|
        single_payload << %{{ "id": #{block.id}, "jsonrpc": "2.0", "method": "get_block_median_time", "params": ["#{block.block_hash}"] }}
      end

      response = CkbSync::Api.instance.directly_batch_call_rpc JSON.parse("[ #{single_payload.join(',')}]")
      response.each do |json_result|
        Block.find(json_result["id"]).update median_timestamp: json_result["result"].to_i(16)
      end
    end
  end

  def update_counter_for_ckb_node_version
    witness = self.cellbase.witnesses[0].data
    return if witness.blank?

    matched = [witness.gsub("0x", "")].pack("H*").match(/\d\.\d+\.\d/)
    if matched.blank?
      Rails.logger.warn "== this block does not have version information from 1st tx's 1st witness: #{witness}"
      return
    end

    # setup global ckb_node_version
    name = "ckb_node_version_#{matched[0]}"
    GlobalStatistic.increment(name)

    # update the current block's ckb_node_version
    self.ckb_node_version = matched[0]
    self.save!
  end

  # NOTICE: this method would do a fresh calculate for all the block's ckb_node_version, it will:
  # 1. delete all the existing ckb_node_version_x.yyy.z
  # 2. do a fresh calculate from block number 1 to the latest block at the moment
  #
  # USAGE:
  # ```bash
  # $ bundle exec rails runner Block.set_ckb_node_versions_from_miner_message
  # ```
  #
  # @param options [Hash]
  def self.set_ckb_node_versions_from_miner_message(options = {})
    GlobalStatistic.where("name like ?", "ckb_node_version_%").delete_all
    to_block_number = options[:to_block_number] || Block.last.number
    # we only need last 100k blocks updated.
    Block.last(100000).each do |block|
      block.update_counter_for_ckb_node_version
    end
  end
end

# == Schema Information
#
# Table name: blocks
#
#  id                         :bigint           not null, primary key
#  block_hash                 :binary
#  number                     :bigint
#  parent_hash                :binary
#  timestamp                  :bigint
#  transactions_root          :binary
#  proposals_hash             :binary
#  uncles_count               :integer
#  extra_hash                 :binary
#  uncle_block_hashes         :binary
#  version                    :integer
#  proposals                  :binary
#  proposals_count            :integer
#  cell_consumed              :bigint
#  miner_hash                 :binary
#  reward                     :decimal(30, )
#  total_transaction_fee      :decimal(30, )
#  ckb_transactions_count     :bigint           default(0)
#  total_cell_capacity        :decimal(30, )
#  epoch                      :bigint
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  address_ids                :string           is an Array
#  reward_status              :integer          default("pending")
#  received_tx_fee_status     :integer          default("pending")
#  received_tx_fee            :decimal(30, )    default(0)
#  target_block_reward_status :integer          default("pending")
#  miner_lock_hash            :binary
#  dao                        :string
#  primary_reward             :decimal(30, )    default(0)
#  secondary_reward           :decimal(30, )    default(0)
#  nonce                      :decimal(50, )    default(0)
#  start_number               :decimal(30, )    default(0)
#  length                     :decimal(30, )    default(0)
#  compact_target             :decimal(20, )
#  live_cell_changes          :integer
#  block_time                 :bigint
#  block_size                 :bigint
#  proposal_reward            :decimal(30, )
#  commit_reward              :decimal(30, )
#  miner_message              :string
#  extension                  :jsonb
#  median_timestamp           :bigint           default(0)
#  ckb_node_version           :string
#  cycles                     :bigint
#
# Indexes
#
#  index_blocks_on_block_hash  (block_hash) USING hash
#  index_blocks_on_block_size  (block_size)
#  index_blocks_on_block_time  (block_time)
#  index_blocks_on_epoch       (epoch)
#  index_blocks_on_number      (number)
#  index_blocks_on_timestamp   (timestamp)
#
