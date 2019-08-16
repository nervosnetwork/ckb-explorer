class ForkedBlock < ApplicationRecord
  enum reward_status: { pending: 0, issued: 1 }
  enum target_block_reward_status: { pending: 0, issued: 1 }, _prefix: :target_block
  enum received_tx_fee_status: { calculating: 0, calculated: 1 }

  attribute :block_hash, :ckb_hash
  attribute :parent_hash, :ckb_hash
  attribute :transactions_root, :ckb_hash
  attribute :proposals_hash, :ckb_hash
  attribute :uncles_hash, :ckb_hash
  attribute :uncle_block_hashes, :ckb_array_hash, hash_length: ENV["DEFAULT_HASH_LENGTH"]
  attribute :proposals, :ckb_array_hash, hash_length: ENV["DEFAULT_SHORT_HASH_LENGTH"]
end

# == Schema Information
#
# Table name: forked_blocks
#
#  id                         :bigint           not null, primary key
#  difficulty                 :string(66)
#  block_hash                 :binary
#  number                     :decimal(30, )
#  parent_hash                :binary
#  seal                       :jsonb
#  timestamp                  :decimal(30, )
#  transactions_root          :binary
#  proposals_hash             :binary
#  uncles_count               :integer
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
#  witnesses_root             :binary
#  epoch                      :decimal(30, )
#  start_number               :string
#  length                     :string
#  address_ids                :string           is an Array
#  reward_status              :integer          default("pending")
#  received_tx_fee_status     :integer          default("calculating")
#  received_tx_fee            :decimal(30, )    default(0)
#  target_block_reward_status :integer          default("pending")
#  miner_lock_hash            :binary
#  dao                        :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
