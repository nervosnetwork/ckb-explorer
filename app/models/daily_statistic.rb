class DailyStatistic < ApplicationRecord
  VALID_INDICATORS = %w(
    transactions_count addresses_count total_dao_deposit live_cells_count dead_cells_count avg_hash_rate avg_difficulty uncle_rate
    total_depositors_count address_balance_distribution total_tx_fee occupied_capacity daily_dao_deposit daily_dao_depositors_count
    circulation_ratio daily_dao_withdraw nodes_count circulating_supply
  ).freeze
end

# == Schema Information
#
# Table name: daily_statistics
#
#  id                           :bigint           not null, primary key
#  transactions_count           :string           default("0")
#  addresses_count              :string           default("0")
#  total_dao_deposit            :string           default("0.0")
#  block_timestamp              :decimal(30, )
#  created_at_unixtimestamp     :integer
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  dao_depositors_count         :string           default("0")
#  unclaimed_compensation       :string           default("0")
#  claimed_compensation         :string           default("0")
#  average_deposit_time         :string           default("0")
#  estimated_apc                :string           default("0")
#  mining_reward                :string           default("0")
#  deposit_compensation         :string           default("0")
#  treasury_amount              :string           default("0")
#  live_cells_count             :string           default("0")
#  dead_cells_count             :string           default("0")
#  avg_hash_rate                :string           default("0")
#  avg_difficulty               :string           default("0")
#  uncle_rate                   :string           default("0")
#  total_depositors_count       :string           default("0")
#  address_balance_distribution :jsonb
#  total_tx_fee                 :decimal(30, )
#  occupied_capacity            :decimal(30, )
#  daily_dao_deposit            :decimal(30, )
#  daily_dao_depositors_count   :integer
#  daily_dao_withdraw           :decimal(30, )
#  circulation_ratio            :decimal(, )
#  total_supply                 :decimal(30, )
#  circulating_supply           :decimal(, )
#  block_time_distribution      :jsonb
#  epoch_time_distribution      :jsonb
#  epoch_length_distribution    :jsonb
#  average_block_time           :jsonb
#  nodes_distribution           :jsonb
#  nodes_count                  :integer
#
