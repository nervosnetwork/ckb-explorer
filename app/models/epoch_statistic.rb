class EpochStatistic < ApplicationRecord
  include AttrLogics

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

  def first_block_in_epoch
    @first_block_in_epoch ||= blocks.order(:number).first
  end

  def last_block_in_epoch
    @last_block_in_epoch ||= blocks.order(number: :desc).first
  end

  define_logic :difficulty do
    first_block_in_epoch.difficulty
  end

  define_logic :uncle_rate do
    uncles_count = blocks.sum(:uncles_count)
    blocks_count = blocks.count
    uncles_count.to_d / blocks_count
  end

  define_logic :hash_rate do
    difficulty = first_block_in_epoch.difficulty
    epoch_length = first_block_in_epoch.length
    epoch_time = last_block_in_epoch.timestamp - first_block_in_epoch.timestamp
    difficulty * epoch_length / epoch_time
  end

  define_logic :epoch_time do
    last_block_in_epoch.timestamp - first_block_in_epoch.timestamp
  end

  define_logic :epoch_length do
    first_block_in_epoch.length
  end

  define_logic :largest_tx_hash do
    largest_tx&.tx_hash
  end

  define_logic :largest_tx_bytes do
    largest_tx&.bytes
  end

  define_logic :max_tx_cycles do
    max_cycles_tx&.cycles
  end

  define_logic :max_block_cycles do
    max_cycles_block&.cycles
  end

  define_logic :largest_block_number do
    largest_block.number
  end

  define_logic :largest_block_size do
    largest_block.block_size
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
