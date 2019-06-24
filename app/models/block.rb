class Block < ApplicationRecord
  MAX_PAGINATES_PER = 100
  paginates_per 10
  max_paginates_per MAX_PAGINATES_PER

  enum status: { inauthentic: 0, authentic: 1, abandoned: 2 }
  enum reward_status: { pending: 0, issued: 1 }
  enum target_block_reward_status: { pending: 0, issued: 1 }, _prefix: :target_block
  enum received_tx_fee_status: { calculating: 0, calculated: 1 }

  has_many :ckb_transactions
  has_many :uncle_blocks
  has_many :cell_outputs

  validates_presence_of :difficulty, :block_hash, :number, :parent_hash, :seal, :timestamp, :transactions_root, :proposals_hash, :uncles_count, :uncles_hash, :version, :cell_consumed, :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, :status, on: :create
  validates :reward, :total_transaction_fee, :ckb_transactions_count, :total_cell_capacity, :cell_consumed, numericality: { greater_than_or_equal_to: 0 }

  attribute :block_hash, :ckb_hash
  attribute :parent_hash, :ckb_hash
  attribute :transactions_root, :ckb_hash
  attribute :proposals_hash, :ckb_hash
  attribute :uncles_hash, :ckb_hash
  attribute :uncle_block_hashes, :ckb_array_hash, hash_length: ENV["DEFAULT_HASH_LENGTH"]
  attribute :proposals, :ckb_array_hash, hash_length: ENV["DEFAULT_SHORT_HASH_LENGTH"]

  scope :recent, -> { order(timestamp: :desc) }
  scope :available, -> { where(status: [:inauthentic, :authentic]) }
  scope :created_after, ->(timestamp) { where("timestamp >= ?", timestamp) }
  scope :created_before, ->(timestamp) { where("timestamp <= ?", timestamp) }

  after_commit :flush_cache

  def verify!(node_block)
    if verified?(node_block.header.hash)
      authenticate!
    else
      abandon!
      CkbSync::Persist.save_block(node_block, "authentic")
    end
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

  def target_block
    @target_block ||= Block.find_by(number: target_block_number)
  end

  def exist_uncalculated_tx?
    ckb_transactions.where(transaction_fee_status: "uncalculated").exists?
  end

  def self.find_block!(query_key)
    cached_find(query_key) || raise(Api::V1::Exceptions::BlockNotFoundError)
  end

  def self.cached_find(query_key)
    Rails.cache.fetch([name, query_key], race_condition_ttl: 3.seconds) do
      if QueryKeyUtils.valid_hex?(query_key)
        where(block_hash: query_key).available.first
      else
        where(number: query_key).available.first
      end
    end
  end

  def miner_address
    Address.find_by(address_hash: miner_hash)
  end

  def cached_ckb_transactions(block_hash, page, page_size, request)
    Rails.cache.fetch([self.class.name, block_hash, "ckb_transactions", page, page_size], race_condition_ttl: 3.seconds) do
      paginated_ckb_transactions = ckb_transactions.available.order(:id).page(page).per(page_size)
      options = FastJsonapi::PaginationMetaGenerator.new(request: request, records: paginated_ckb_transactions, page: page, page_size: page_size).call
      CkbTransactionSerializer.new(paginated_ckb_transactions, options).serialized_json
    end
  end

  def flush_cache
    Rails.cache.delete([self.class.name, block_hash])
    Rails.cache.delete([self.class.name, number])
    Rails.cache.delete_matched("#{self.class.name}/#{block_hash}/ckb_transactions/*")
  end

  private

  def verified?(node_block_hash)
    block_hash == node_block_hash
  end

  def authenticate!
    update!(status: "authentic")
    SyncInfo.find_by!(name: "authentic_tip_block_number", value: number).update_attribute(:status, "synced")
    ChangeCkbTransactionsStatusWorker.perform_async(id, "authentic")
    self
  end

  def abandon!
    update!(status: "abandoned", reward_status: "issued")
    ChangeCkbTransactionsStatusWorker.perform_async(id, "abandoned")
    ChangeCellOutputsStatusWorker.perform_async(id, "abandoned")
  end
end

# == Schema Information
#
# Table name: blocks
#
#  id                     :bigint           not null, primary key
#  difficulty             :string(66)
#  block_hash             :binary
#  number                 :decimal(30, )
#  parent_hash            :binary
#  seal                   :jsonb
#  timestamp              :decimal(30, )
#  transactions_root      :binary
#  proposals_hash         :binary
#  uncles_count           :integer
#  uncles_hash            :binary
#  uncle_block_hashes     :binary
#  version                :integer
#  proposals              :binary
#  proposals_count        :integer
#  cell_consumed          :decimal(30, )
#  miner_hash             :binary
#  status                 :integer
#  reward                 :decimal(30, )
#  total_transaction_fee  :decimal(30, )
#  ckb_transactions_count :decimal(30, )    default(0)
#  total_cell_capacity    :decimal(30, )
#  witnesses_root         :binary
#  epoch                  :decimal(30, )
#  start_number           :string
#  length                 :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  address_ids            :string           is an Array
#  reward_status          :integer          default("pending")
#  received_tx_fee_status :integer          default("calculating")
#  received_tx_fee        :decimal(30, )    default(0)
#  target_block_reward_status :integer          default(0)

#
# Indexes
#
#  index_blocks_on_block_hash  (block_hash) UNIQUE
#  index_blocks_on_number      (number)
#  index_blocks_on_timestamp   (timestamp)
#
