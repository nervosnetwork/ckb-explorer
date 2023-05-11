class BlockStatistic < ApplicationRecord
  include AttrLogics
  VALID_INDICATORS = %w(difficulty hash_rate live_cells_count dead_cells_count).freeze
  belongs_to :block, foreign_key: :block_number, primary_key: :number, optional: true
  delegate :block_hash, to: :block

  CkbToShannon = 10**8

  def get_block_economic_state
    @get_block_economic_state ||= CkbSync::Api.instance.get_block_economic_state(block_hash)
  end

  # has '0x' prefix
  def dao_infos
    @dao_infos ||= [block.dao[2..]].pack("H*").unpack("Q<4").map { |i| i.to_d / CkbToShannon }
  end

  define_logic :primary_issuance do
    val = get_block_economic_state&.issuance&.primary || 0
    val.to_d / CkbToShannon
  end

  define_logic :secondary_issuance do
    val = get_block_economic_state&.issuance&.secondary || 0
    val.to_d / CkbToShannon
  end

  define_logic :accumulated_total_deposits do
    dao_infos[0]
  end

  define_logic :accumulated_rate do
    dao_infos[1]
  end

  define_logic :unissued_secondary_issuance do
    dao_infos[2]
  end

  define_logic :total_occupied_capacities do
    dao_infos[3]
  end

  def reset_all
    reset_primary_issuance
    reset_secondary_issuance
    reset_accumulated_total_deposits
    reset_accumulated_rate
    reset_unissued_secondary_issuance
    reset_total_occupied_capacities
  end

  def self.full_reset
    find_each do |s|
      puts s.block_number
      s.reset_all
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
#  block_number                :bigint
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  epoch_number                :bigint
#  primary_issuance            :decimal(36, 8)
#  secondary_issuance          :decimal(36, 8)
#  accumulated_total_deposits  :decimal(36, 8)
#  accumulated_rate            :decimal(36, 8)
#  unissued_secondary_issuance :decimal(36, 8)
#  total_occupied_capacities   :decimal(36, 8)
#
# Indexes
#
#  index_block_statistics_on_block_number  (block_number) UNIQUE
#
