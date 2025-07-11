class ForkedBlock < ApplicationRecord
  enum reward_status: { pending: 0, issued: 1 }
  enum target_block_reward_status: { pending: 0, issued: 1 }, _prefix: :target_block
  enum received_tx_fee_status: { pending: 0, calculated: 1 }, _prefix: :current_block

  attribute :block_hash, :ckb_hash
  attribute :parent_hash, :ckb_hash
  attribute :transactions_root, :ckb_hash
  attribute :proposals_hash, :ckb_hash
  attribute :extra_hash, :ckb_hash
  attribute :uncle_block_hashes, :ckb_array_hash, hash_length: Settings.default_hash_length
  attribute :proposals, :ckb_array_hash, hash_length: Settings.default_short_hash_length
end

# == Schema Information
#
# Table name: forked_blocks
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
#  cell_consumed              :decimal(30, )
#  miner_hash                 :binary
#  reward                     :decimal(30, )
#  total_transaction_fee      :decimal(30, )
#  ckb_transactions_count     :decimal(30, )    default(0)
#  total_cell_capacity        :decimal(30, )
#  epoch                      :bigint
#  address_ids                :string           is an Array
#  reward_status              :integer          default("pending")
#  received_tx_fee_status     :integer          default("pending")
#  received_tx_fee            :decimal(30, )    default(0)
#  target_block_reward_status :integer          default("pending")
#  miner_lock_hash            :binary
#  dao                        :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  primary_reward             :decimal(30, )    default(0)
#  secondary_reward           :decimal(30, )    default(0)
#  nonce                      :decimal(50, )    default(0)
#  start_number               :decimal(30, )    default(0)
#  length                     :decimal(30, )    default(0)
#  compact_target             :decimal(20, )
#  live_cell_changes          :integer
#  block_time                 :decimal(13, )
#  block_size                 :integer
#  proposal_reward            :decimal(30, )
#  commit_reward              :decimal(30, )
#  miner_message              :string
#  extension                  :jsonb
#  median_timestamp           :decimal(, )      default(0.0)
#  ckb_node_version           :string
#  cycles                     :bigint
#  difficulty                 :decimal(78, )
#
