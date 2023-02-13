class Block < ApplicationRecord
  MAX_PAGINATES_PER = 100
  paginates_per 10
  max_paginates_per MAX_PAGINATES_PER

  enum reward_status: { pending: 0, issued: 1 }
  enum target_block_reward_status: { pending: 0, issued: 1 }, _prefix: :target_block
  enum received_tx_fee_status: { pending: 0, calculated: 1 }, _prefix: :current_block

  has_many :ckb_transactions
  has_many :uncle_blocks
  has_many :cell_outputs
  has_many :cell_inputs
  has_many :dao_events
  has_many :mining_infos
  belongs_to :epoch_statistic, primary_key: :epoch_number, foreign_key: :epoch, optional: true

  validates_presence_of :block_hash, :number, :parent_hash, :timestamp, :transactions_root, :proposals_hash, :uncles_count, :extra_hash, :version, :cell_consumed, :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, on: :create
  validates :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, :cell_consumed, numericality: { greater_than_or_equal_to: 0 }

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
  scope :h24, -> { where("timestamp > ?", 24.hours.ago.to_datetime.strftime("%Q")) }

  after_commit :flush_cache

  def self.last_7_days_ckb_node_version
    from = 7.days.ago.to_i * 1000
    sql = "select ckb_node_version, count(*) from blocks where timestamp >= #{from} group by ckb_node_version order by 1 asc;"
    return ActiveRecord::Base.connection.execute(sql).values
  end

  def raw_block
    @raw_block ||=
      Rails.cache.fetch(["raw_block", number], expires_in: 10.minutes) do
        CkbSync::Api.instance.get_block_by_number(number)
      end
  end

  def get_block_cycles
    @block_cycles ||= CkbSync::Api.instance.get_block_cycles(block_hash)
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
    number - ENV["PROPOSAL_WINDOW"].to_i - 1
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
    Rails.cache.realize([name, query_key], race_condition_ttl: 3.seconds) do
      if QueryKeyUtils.valid_hex?(query_key)
        block = where(block_hash: query_key).first
      else
        block = where(number: query_key).first
      end
      BlockSerializer.new(block) if block.present?
    end
  end

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
    Address.find_by_address_hash(miner_hash, address_hash_crc: CkbUtils.generate_crc32(miner_hash))
  end

  def flush_cache
    $redis.pipelined do
      $redis.del(*cache_keys)
    end
  end

  def cache_keys
    %W(#{self.class.name}/#{block_hash} #{self.class.name}/#{number})
  end

  def invalid!
    uncle_blocks.delete_all
    delete_address_txs_cache
    delete_tx_display_infos
    ckb_transactions.destroy_all
    ForkedBlock.create(attributes)
    destroy
  end

  # update existing block data. to update its median_timestamp
  # only run once.
  # usage:
  # 1. bundle exec rails console
  # 2. Block.update_block_median_timestamp <block_number>
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
    witness = self.ckb_transactions.first.witnesses[0]
    return if witness.blank?

    matched = [witness.gsub("0x", "")].pack("H*").match(/\d\.\d+\.\d/)
    if matched.blank?
      Rails.logger.warn "== this block does not have version information from 1st tx's 1st witness: #{witness}"
      return
    end

    # setup global ckb_node_version
    name = "ckb_node_version_#{matched[0]}"
    global_statistic = GlobalStatistic.find_or_create_by(name: name)
    global_statistic.increment!(:value)

    # update the current block's ckb_node_version
    self.ckb_node_version = matched[0]
    self.save!
  end

  # NOTICE: this method would do a fresh calculate for all the block's ckb_node_version, it will:
  # 1. delete all the existing ckb_node_version_x.yyy.z
  # 2. do a fresh calculate from block number 1 to the latest block at the moment
  #
  # USAGE:
  #
  # $ bundle exec rails c
  # rails> Block.set_ckb_node_versions_from_miner_message
  #
  def self.set_ckb_node_versions_from_miner_message(options = {})
    GlobalStatistic.where("name like ?", "ckb_node_version_%").delete_all
    to_block_number = options[:to_block_number] || Block.last.number
    # we only need last 100k blocks updated.
    Block.last(100000).each do |block|
      block.update_counter_for_ckb_node_version
    end
  end

  private

  def delete_tx_display_infos
    TxDisplayInfo.where(ckb_transaction_id: ckb_transactions.ids).delete_all
  end

  def delete_address_txs_cache
    address_txs = Hash.new
    ckb_transactions.each do |tx|
      tx.contained_address_ids.each do |id|
        if address_txs[id].present?
          address_txs[id] << tx.id
        else
          address_txs[id] = [tx.id]
        end
      end
    end
    service = ListCacheService.new
    $redis.pipelined do
      address_txs.each do |k, v|
        members = CkbTransaction.where(id: v).select(:id, :tx_hash, :block_id, :block_number, :block_timestamp, :is_cellbase, :updated_at).map(&:to_json)
        service.zrem("Address/txs/#{k}", members)
      end
    end
  end
end

# == Schema Information
#
# Table name: blocks
#
#  id                         :bigint           not null, primary key
#  block_hash                 :binary
#  number                     :decimal(30, )
#  parent_hash                :binary
#  timestamp                  :decimal(30, )
#  transactions_root          :binary
#  proposals_hash             :binary
#  extra_hash                 :binary
#  uncle_block_hashes         :binary
#  version                    :integer
#  proposals                  :binary
#  proposals_count            :integer
#  cell_consumed              :decimal(30, )
#  miner_hash                 :binary
#  reward                     :decimal(30, )
#  total_transaction_fee      :decimal(30, )
#  ckb_transactions_count     :decimal(30, )    default(0)
#  total_cell_capacity        :decimal(30, )
#  epoch                      :decimal(30, )
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
#  uncles_count               :integer
#  compact_target             :decimal(20, )
#  live_cell_changes          :integer
#  block_time                 :decimal(13, )
#  block_size                 :integer
#  proposal_reward            :decimal(30, )
#  commit_reward              :decimal(30, )
#  miner_message              :string
#  extension                  :jsonb
#  median_timestamp           :decimal(, )      default(0.0)
#  cycles                     :bigint
#  ckb_node_version           :string
#
# Indexes
#
#  index_blocks_on_block_hash  (block_hash) UNIQUE
#  index_blocks_on_block_size  (block_size)
#  index_blocks_on_block_time  (block_time)
#  index_blocks_on_epoch       (epoch)
#  index_blocks_on_number      (number)
#  index_blocks_on_timestamp   (timestamp)
#
