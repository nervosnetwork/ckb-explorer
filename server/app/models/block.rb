class Block < ApplicationRecord
  MAX_PAGINATES_PER = 100
  paginates_per 10
  max_paginates_per MAX_PAGINATES_PER

  enum status: { inauthentic: 0, authentic: 1, abandoned: 2 }

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

  def self.find_block(query_key)
    if QueryKeyUtils.valid_hex?(query_key)
      where(block_hash: query_key).available.take!
    else
      where(number: query_key).available.take!
    end
  rescue ActiveRecord::RecordNotFound
    raise Api::V1::Exceptions::BlockNotFoundError
  end

  private

  def verified?(node_block_hash)
    block_hash == node_block_hash
  end

  def authenticate!
    update!(status: "authentic")
    SyncInfo.find_by!(name: "authentic_tip_block_number", value: number).update_attribute(:status, "synced")
    ChangeCkbTransactionsStatusWorker.perform_async(id, "authentic")
  end

  def abandon!
    update!(status: "abandoned")
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
#
# Indexes
#
#  index_blocks_on_block_hash             (block_hash) UNIQUE
#  index_blocks_on_block_hash_and_status  (block_hash,status)
#  index_blocks_on_number_and_status      (number,status)
#  index_blocks_on_status                 (status)
#  index_blocks_on_timestamp              (timestamp)
#
