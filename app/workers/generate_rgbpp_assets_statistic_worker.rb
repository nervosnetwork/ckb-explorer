class GenerateRgbppAssetsStatisticWorker
  include Sidekiq::Job
  sidekiq_options queue: "rgbpp"

  attr_accessor :datetime

  def perform(datetime = nil)
    @datetime = datetime
    statistic_attributes = [
      ft_count_attributes,
      dob_count_attributes,
      btc_transactions_count_attributes,
      ckb_transactions_count_attributes,
      btc_holders_count_attributes,
      ckb_holders_count_attributes,
    ]
    statistic_attributes.each { _1[:created_at_unixtimestamp] = started_at.to_i }
    RgbppAssetsStatistic.upsert_all(statistic_attributes, unique_by: %i[indicator network created_at_unixtimestamp])
  rescue StandardError => e
    Rails.logger.error "Error occurred during GenerateRgbppHourlyStatistic error: #{e.message}"
  end

  private

  def ft_count_attributes
    timestamp = CkbUtils.time_in_milliseconds(ended_at) - 1
    scope = Udt.where(udt_type: %i[xudt xudt_compatible], block_timestamp: ..timestamp)
    xudts_count = scope.joins(:xudt_tag).where("xudt_tags.tags && ARRAY[?]::varchar[]", ["rgb++"])
    { indicator: "ft_count", value: xudts_count, network: "global" }
  end

  def dob_count_attributes
    timestamp = CkbUtils.time_in_milliseconds(ended_at) - 1
    token_collections_count = TokenCollection.where("tags && ARRAY[?]::varchar[]", ["rgb++"]).
      where(block_timestamp: ..timestamp).count
    { indicator: "dob_count", value: token_collections_count, network: "global" }
  end

  def btc_transactions_count_attributes
<<<<<<< HEAD
    transactions_count = BitcoinTransaction.where(time: started_at.to_i..ended_at.to_i).count
=======
    transactions_count = BitcoinTransaction.where(time: ..ended_at.to_i).count
>>>>>>> 569480db1d55fb5b98658c4198219c13f77089e5
    { indicator: "transactions_count", value: transactions_count, network: "btc" }
  end

  def ckb_transactions_count_attributes
<<<<<<< HEAD
    started_timestamp = CkbUtils.time_in_milliseconds(started_at)
    ended_timestamp = CkbUtils.time_in_milliseconds(ended_at) - 1
    transactions_count = BitcoinAnnotation.includes(:ckb_transaction).
      where(ckb_transactions: { block_timestamp: started_timestamp..ended_timestamp }).count
=======
    ended_timestamp = CkbUtils.time_in_milliseconds(ended_at) - 1
    transactions_count = BitcoinAnnotation.includes(:ckb_transaction).
      where(ckb_transactions: { block_timestamp: ..ended_timestamp }).count
>>>>>>> 569480db1d55fb5b98658c4198219c13f77089e5
    { indicator: "transactions_count", value: transactions_count, network: "ckb" }
  end

  def btc_holders_count_attributes
    udt_types = %i[xudt xudt_compatible spore_cell did_cell]
    udt_ids = Udt.where(udt_type: udt_types, published: true).ids
    address_ids = UdtAccount.where(udt_id: udt_ids).where("amount > 0").pluck(:address_id).uniq
    holders_count = BitcoinAddressMapping.where(ckb_address_id: address_ids, created_at: ..ended_at).
      distinct.count(:bitcoin_address_id)
    { indicator: "holders_count", value: holders_count, network: "btc" }
  end

  def ckb_holders_count_attributes
    udt_types = %i[xudt xudt_compatible spore_cell did_cell]
    udt_ids = Udt.where(udt_type: udt_types, published: true).ids
    holders_count = UdtAccount.where(udt_id: udt_ids, created_at: ..ended_at).
      where("amount > 0").distinct.count(:address_id)
    { indicator: "holders_count", value: holders_count, network: "ckb" }
  end

  def to_be_counted_date
    if @datetime.present?
<<<<<<< HEAD
      return Time.zone.parse(@datetime)
=======
      return Time.parse(@datetime)
>>>>>>> 569480db1d55fb5b98658c4198219c13f77089e5
    end

    last_record = UdtHourlyStatistic.order(created_at_unixtimestamp: :desc).first
    if last_record
<<<<<<< HEAD
      Time.zone.at(last_record.created_at_unixtimestamp) + 1.day
    else
      Time.current.yesterday
=======
      Time.at(last_record.created_at_unixtimestamp) + 1.day
    else
      Time.now.yesterday
>>>>>>> 569480db1d55fb5b98658c4198219c13f77089e5
    end
  end

  def started_at
    @started_at ||= to_be_counted_date.beginning_of_day
  end

  def ended_at
    @ended_at ||= to_be_counted_date.end_of_day
  end
end
