class BitcoinStatistic < ApplicationRecord
  default_scope { order(timestamp: :asc) }

  def self.refresh
    transaction do
      current_time = Time.current
      start_time = Time.zone.local(current_time.year, current_time.month, current_time.day, current_time.hour, current_time.min < 30 ? 0 : 30)
      end_time = start_time + 30.minutes

      # Count the number of newly generated addresses within half an hour before the current time point
      addresses_count = BitcoinAddress.where(created_at: start_time..end_time).count
      # Count the number of newly generated transactions within half an hour before the current time point
      transactions_count = BitcoinTransaction.where(created_at: start_time..end_time).count
      create!(timestamp: end_time.utc.to_i * 1000, addresses_count:, transactions_count:)
    end
  end
end

# == Schema Information
#
# Table name: bitcoin_statistics
#
#  id                 :bigint           not null, primary key
#  timestamp          :bigint
#  transactions_count :integer          default(0)
#  addresses_count    :integer          default(0)
#
# Indexes
#
#  index_bitcoin_statistics_on_timestamp  (timestamp) UNIQUE
#
