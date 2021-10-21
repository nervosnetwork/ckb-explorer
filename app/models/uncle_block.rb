class UncleBlock < ApplicationRecord
  belongs_to :block

  validates_presence_of :compact_target, :block_hash, :number, :parent_hash, :timestamp, :transactions_root, :proposals_hash, :extra_hash, :version

  attribute :block_hash, :ckb_hash
  attribute :parent_hash, :ckb_hash
  attribute :transactions_root, :ckb_hash
  attribute :proposals_hash, :ckb_hash
  attribute :extra_hash, :ckb_hash
  attribute :proposals, :ckb_array_hash, hash_length: ENV["DEFAULT_SHORT_HASH_LENGTH"]

  def difficulty
    CkbUtils.compact_to_difficulty(compact_target)
  end
end

# == Schema Information
#
# Table name: uncle_blocks
#
#  id                :bigint           not null, primary key
#  block_hash        :binary
#  number            :decimal(30, )
#  parent_hash       :binary
#  timestamp         :decimal(30, )
#  transactions_root :binary
#  proposals_hash    :binary
#  uncles_hash       :binary
#  version           :integer
#  proposals         :binary
#  proposals_count   :integer
#  block_id          :bigint
#  epoch             :decimal(30, )
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  dao               :string
#  nonce             :decimal(50, )    default(0)
#  compact_target    :decimal(20, )
#
# Indexes
#
#  index_uncle_blocks_on_block_hash_and_block_id  (block_hash,block_id) UNIQUE
#  index_uncle_blocks_on_block_id                 (block_id)
#
