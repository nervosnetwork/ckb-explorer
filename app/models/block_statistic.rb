class BlockStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty hash_rate live_cells_count dead_cells_count).freeze
  belongs_to :block, foreign_key: :block_number, primary_key: :number, optional: true
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

  # has '0x' prefix
  def dao_infos
    @values ||= [block.dao[2..-1]].pack("H*").unpack("Q<4").map { |i| i.to_d / CkbToShannon }
  end

  def reset_accumulated_total_deposits
    self.accumulated_total_deposits = dao_infos[0]
  end

  def reset_accumulated_rate
    self.accumulated_rate = dao_infos[1]
  end

  def reset_unissued_secondary_issuance
    self.unissued_secondary_issuance = dao_infos[2]
  end

  def reset_total_occupied_capacities
    self.total_occupied_capacities = dao_infos[3]
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
