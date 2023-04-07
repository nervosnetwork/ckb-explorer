class EpochStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty uncle_rate hash_rate epoch_time epoch_length).freeze
  has_many :blocks, primary_key: :epoch_number, foreign_key: :epoch
  has_many :ckb_transactions, through: :blocks
  def max_cycles_block
    @max_cycles_block ||= blocks.where.not(cycles: nil).order(cycles: :desc).first
  end

  def max_cycles_tx
    @max_cycles_tx ||= ckb_transactions.where.not(cycles: nil).order(cycles: :desc).first
  end

  def largest_block
    @largest_block ||= blocks.where.not(block_size: nil).order(block_size: :desc).first
  end

  def largest_tx
    @largest_tx ||= ckb_transactions.where.not(bytes: nil).order(bytes: :desc).first
  end

  def reset_largest_tx_hash
    self.largest_tx_hash = largest_tx&.tx_hash
  end

  def reset_largest_tx_bytes
    self.largest_tx_bytes = largest_tx&.bytes
  end

  def reset_max_tx_cycles
    self.max_tx_cycles = max_cycles_tx&.cycles
  end

  def reset_max_block_cycles
    self.max_block_cycles = max_cycles_block&.cycles
  end

  def reset_largest_block_number
    self.largest_block_number = largest_block.number
    self.largest_block_size = largest_block.block_size
  end

  def reset_largest_block_size
    self.largest_block_size = largest_block.block_size
  end

  def self.largest_block_size
    Rails.cache.fetch("largest_block_size", expires_in: 10.minutes) do
      EpochStatistic.maximum(:largest_block_size)
    end
  end

  def self.largest_tx_bytes
    Rails.cache.fetch("largest_tx_bytes", expires_in: 10.minutes) do
      EpochStatistic.maximum(:largest_tx_bytes)
    end
  end

  def self.max_block_cycles
    Rails.cache.fetch("max_block_cycles", expires_in: 10.minutes) do
      EpochStatistic.maximum(:max_block_cycles)
    end
  end

  def self.max_tx_cycles
    Rails.cache.fetch("max_tx_cycles", expires_in: 10.minutes) do
      EpochStatistic.maximum(:max_tx_cycles)
    end
  end
end

# == Schema Information
#
# Table name: epoch_statistics
#
#  id                   :bigint           not null, primary key
#  difficulty           :string
#  uncle_rate           :string
#  epoch_number         :bigint
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  hash_rate            :string
#  epoch_time           :bigint
#  epoch_length         :integer
#  largest_block_number :integer
#  largest_block_size   :integer
#  largest_tx_hash      :binary
#  largest_tx_bytes     :integer
#  max_block_cycles     :bigint
#  max_tx_cycles        :integer
#
# Indexes
#
#  index_epoch_statistics_on_epoch_number  (epoch_number) UNIQUE
#
