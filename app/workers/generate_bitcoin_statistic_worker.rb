class GenerateBitcoinStatisticWorker
  include Sidekiq::Job
  sidekiq_options queue: "rgbpp"

  attr_accessor :datetime

  def perform
    start_time, end_time = time_range
    statistic_attributes = [
      btc_attributes(start_time, end_time),
      ckb_attributes(start_time, end_time),
    ]

    Rails.logger.info "update bitcoin_statistics #{statistic_attributes}"

    BitcoinStatistic.upsert_all(statistic_attributes, unique_by: %i[timestamp network])
  rescue StandardError => e
    Rails.logger.error "Error occurred during GenerateRgbppHourlyStatistic error: #{e.message}"
  end

  private

  def btc_attributes(start_time, end_time)
    addresses_count = BitcoinAddress.where(created_at: start_time..end_time).count
    transactions_count = BitcoinTransaction.where(created_at: start_time..end_time).count
    timestamp = end_time.utc.to_i * 1000
    { timestamp:, addresses_count:, transactions_count:, network: :btc }
  end

  def ckb_attributes(start_time, end_time)
    start_timestamp = CkbUtils.time_in_milliseconds(start_time)
    end_timestamp = CkbUtils.time_in_milliseconds(end_time) - 1

    ft_transaction_ids = Set.new
    Udt.where(udt_type: %i[xudt xudt_compatible]).find_each do |xudt|
      ft_transaction_ids.merge(xudt.ckb_transactions.where(block_timestamp: start_timestamp..end_timestamp).ids)
    end

    dob_transaction_ids = Set.new
    TokenCollection.spore.find_each do |token_collection|
      transfers = token_collection.transfers.joins(:ckb_transaction).
        where("ckb_transactions.block_timestamp >= ?", start_timestamp).
        where("ckb_transactions.block_timestamp < ?", end_timestamp)

      dob_transaction_ids.merge(transfers.map(&:transaction_id))
    end

    transactions_count = ft_transaction_ids.length + dob_transaction_ids.length
    timestamp = end_time.utc.to_i * 1000
    { timestamp:, transactions_count:, network: :ckb }
  end

  def time_range
    current_time = Time.current
    end_time = Time.zone.local(current_time.year, current_time.month, current_time.day, current_time.hour, current_time.min)
    start_time = end_time - 30.minutes

    Rails.logger.info "current_time: #{current_time}, start_time: #{start_time}, end_time: #{end_time}"

    [start_time, end_time]
  end
end
