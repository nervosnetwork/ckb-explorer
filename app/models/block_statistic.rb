class BlockStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty hash_rate live_cells_count dead_cells_count).freeze
  belongs_to :block, foreign_key: :block_number, primary_key: :number
  delegate :block_hash, to: :block
  CkbToShannon = 10**8
  def reset_primary_issuance
    val = get_block_economic_state&.issuance&.primary || 0
    self.primary_issuance = val.to_d / CkbToShannon
  end

  def reset_secondary_issuance
    val = get_block_economic_state&.issuance&.secondary || 0
    self.secondary_issuance = val.to_d / CkbToShannon
  end

  def get_block_economic_state
    @res ||= CkbSync::Api.instance.get_block_economic_state(block_hash)
  end

  def self.full_reset
    find_each do |s|
      puts s.block_number
      s.reset_primary_issuance
      s.reset_secondary_issuance
      s.save
    end
  end
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
