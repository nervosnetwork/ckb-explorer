class EpochStatistic < ApplicationRecord
  VALID_INDICATORS = %w(difficulty uncle_rate hash_rate epoch_time epoch_length).freeze

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
end

# == Schema Information
#
# Table name: epoch_statistics
#
#  id                   :bigint           not null, primary key
#  difficulty           :string
#  uncle_rate           :string
#  epoch_number         :decimal(30, )
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  hash_rate            :string
#  epoch_time           :decimal(13, )
#  epoch_length         :integer
#  largest_block_number :integer
#  largest_block_size   :integer
#  largest_tx_hash      :binary
#  largest_tx_bytes     :integer
#
# Indexes
#
#  index_epoch_statistics_on_epoch_number  (epoch_number) UNIQUE
#
