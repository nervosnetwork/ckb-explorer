class DailyStatistic < ApplicationRecord
  VALID_INDICATORS = %w(transactions_count addresses_count total_dao_deposit).freeze
end

# == Schema Information
#
# Table name: daily_statistics
#
#  id                       :bigint           not null, primary key
#  transactions_count       :string           default("0")
#  addresses_count          :string           default("0")
#  total_dao_deposit        :string           default("0.0")
#  block_timestamp          :decimal(30, )
#  created_at_unixtimestamp :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  dao_depositors_count     :string           default("0")
#  unclaimed_compensation   :string           default("0")
#  claimed_compensation     :string           default("0")
#  average_deposit_time     :string           default("0")
#  estimated_apc            :string           default("0")
#  mining_reward            :string           default("0")
#  deposit_compensation     :string           default("0")
#  treasury_amount          :string           default("0")
#  live_cells_count         :string           default("0")
#  dead_cells_count         :string           default("0")
#  avg_hash_rate            :string           default("0")
#  avg_difficulty           :string           default("0")
#  uncle_rate               :string           default("0")
#  total_depositors_count   :string           default("0")
#
