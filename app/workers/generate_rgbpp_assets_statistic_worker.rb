class GenerateRgbppAssetsStatisticWorker
  include Sidekiq::Job
  sidekiq_options queue: "rgbpp"

  def perform
    statistic_attributes = [
      ft_count_attributes,
      dob_count_attributes,
      btc_transactions_count_attributes,
      ckb_transactions_count_attributes,
      btc_holders_count_attributes,
      ckb_holders_count_attributes,
    ]

    puts "===="
    puts statistic_attributes
    statistic_attributes.each { _1[:created_at_unixtimestamp] = started_at.to_i }
    RgbppAssetsStatistic.upsert_all(statistic_attributes, unique_by: %i[indicator network created_at_unixtimestamp])
  rescue StandardError => e
    Rails.logger.error "Error occurred during GenerateRgbppHourlyStatistic error: #{e.message}"
  end

  private

  def ft_count_attributes
    xudts_count = Udt.published_xudt.joins(:xudt_tag).where("xudt_tags.tags && ARRAY[?]::varchar[]", ["rgb++"]).count
    { indicator: "ft_count", value: xudts_count, network: "global" }
  end

  def dob_count_attributes
    token_collections_count = TokenCollection.where("tags && ARRAY[?]::varchar[]", ["rgb++"]).count
    { indicator: "dob_count", value: token_collections_count, network: "global" }
  end

  def btc_transactions_count_attributes
    transactions_count = BitcoinTransaction.where(time: started_at.to_i..ended_at.to_i).count
    { indicator: "transactions_count", value: transactions_count, network: "btc" }
  end

  def ckb_transactions_count_attributes
    started_timestamp = CkbUtils.time_in_milliseconds(started_at)
    ended_timestamp = CkbUtils.time_in_milliseconds(ended_at) - 1
    transactions_count = BitcoinAnnotation.includes(:ckb_transaction).
      where(ckb_transactions: { block_timestamp: started_timestamp..ended_timestamp }).count
    { indicator: "transactions_count", value: transactions_count, network: "ckb" }
  end

  def btc_holders_count_attributes
    udt_types = %i[xudt xudt_compatible spore_cell did_cell]
    udt_ids = Udt.where(udt_type: udt_types, published: true).ids
    address_ids = UdtAccount.where(udt_id: udt_ids).where("amount > 0").pluck(:address_id).uniq
    holders_count = BitcoinAddressMapping.where(ckb_address_id: address_ids).distinct.count(:bitcoin_address_id)
    { indicator: "holders_count", value: holders_count, network: "btc" }
  end

  def ckb_holders_count_attributes
    udt_types = %i[xudt xudt_compatible spore_cell did_cell]
    udt_ids = Udt.where(udt_type: udt_types, published: true).ids
    holders_count = UdtAccount.where(udt_id: udt_ids).where("amount > 0").distinct.count(:address_id)
    { indicator: "holders_count", value: holders_count, network: "ckb" }
  end

  def to_be_counted_date
    last_record = UdtHourlyStatistic.order(created_at_unixtimestamp: :desc).first
    if last_record
      Time.zone.at(last_record.created_at_unixtimestamp) + 1.day
    else
      Time.current.yesterday
    end
  end

  def started_at
    @started_at ||= to_be_counted_date.beginning_of_day
  end

  def ended_at
    @ended_at ||= to_be_counted_date.end_of_day
  end
end
