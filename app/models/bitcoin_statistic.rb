class BitcoinStatistic < ApplicationRecord
  default_scope { order(timestamp: :asc) }

  def self.refresh
    transaction do
      current_time = Time.current
      end_time = Time.zone.local(current_time.year, current_time.month, current_time.day, current_time.hour, current_time.min)
      start_time = end_time - 30.minutes

      Rails.logger.info "current_time: #{current_time}, start_time: #{start_time}, end_time: #{end_time}"

      # Count the number of newly generated addresses within half an hour before the current time point
      addresses_count = BitcoinAddress.where(created_at: start_time..end_time).count
      # Count the number of newly generated transactions within half an hour before the current time point
      transactions_count = BitcoinTransaction.where(created_at: start_time..end_time).count
      Rails.logger.info "update bitcoin_statistics addresses_count(#{addresses_count}) transactions_count(#{transactions_count})"

      statistic = BitcoinStatistic.find_or_initialize_by(timestamp: end_time.utc.to_i * 1000)
      statistic.addresses_count = addresses_count
      statistic.transactions_count = transactions_count
      statistic.save!
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
#  index_bitcoin_statistics_on_timestamp  (timestamp)
#
