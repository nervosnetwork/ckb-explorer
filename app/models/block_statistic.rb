class BlockStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty hash_rate live_cells_count dead_cells_count).freeze
end

# == Schema Information
#
# Table name: block_statistics
#
#  id                          :bigint           not null, primary key
#  difficulty                  :string
#  hash_rate                   :string
#  live_cells_count            :string           default("0")
#  dead_cells_count            :string           default("0")
#  block_number                :decimal(30, )
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  epoch_number                :decimal(30, )
#  primary_issuance            :decimal(36, 8)
#  secondary_issuance          :decimal(36, 8)
#  total_issuance              :decimal(36, 8)
#  accumulated_rate            :decimal(36, 8)
#  unissued_secondary_issuance :decimal(36, 8)
#  total_occupied_capacities   :decimal(36, 8)
#
# Indexes
#
#  index_block_statistics_on_block_number  (block_number) UNIQUE
#
