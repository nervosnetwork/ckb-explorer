class BlockStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty hash_rate live_cells_count dead_cells_count)
end

# == Schema Information
#
# Table name: block_statistics
#
#  id               :bigint           not null, primary key
#  difficulty       :string
#  hash_rate        :string
#  live_cells_count :string           default("0")
#  dead_cells_count :string           default("0")
#  block_number     :decimal(30, )
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  epoch_number     :decimal(30, )
#
# Indexes
#
#  index_block_statistics_on_block_number  (block_number) UNIQUE
#
