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

  validates_presence_of :block_hash, :number, :parent_hash, :timestamp, :transactions_root, :proposals_hash, :uncles_count, :uncles_hash, :version, :cell_consumed, :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, on: :create
  validates :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, :cell_consumed, numericality: { greater_than_or_equal_to: 0 }

  attribute :block_hash, :ckb_hash
  attribute :parent_hash, :ckb_hash
  attribute :transactions_root, :ckb_hash
  attribute :proposals_hash, :ckb_hash
  attribute :uncles_hash, :ckb_hash
  attribute :uncle_block_hashes, :ckb_array_hash, hash_length: ENV["DEFAULT_HASH_LENGTH"]
  attribute :proposals, :ckb_array_hash, hash_length: ENV["DEFAULT_SHORT_HASH_LENGTH"]

  scope :recent, -> { order(timestamp: :desc) }
  scope :created_after, ->(timestamp) { where("timestamp >= ?", timestamp) }
  scope :created_before, ->(timestamp) { where("timestamp <= ?", timestamp) }

  after_commit :flush_cache

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

  def miner_address
    Address.find_by(address_hash: miner_hash)
  end

  def flush_cache
    Rails.cache.delete([self.class.name, block_hash])
    Rails.cache.delete([self.class.name, number])
  end

  def invalid!
    uncle_blocks.delete_all
    ckb_transactions.destroy_all
    ForkedBlock.create(attributes)
    destroy
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
#  uncles_hash                :binary
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
#
# Indexes
#
#  index_blocks_on_block_hash  (block_hash) UNIQUE
#  index_blocks_on_number      (number)
#  index_blocks_on_timestamp   (timestamp)
#
