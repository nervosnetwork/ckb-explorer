class GenerateRgbppHourlyStatisticWorker
  include Sidekiq::Job

  def perform
    xudts_count = Udt.published_xudt.joins(:xudt_tag).where("xudt_tags.tags && ARRAY[?]::varchar[]", ["rgb++"]).count
    nft_collections_count = TokenCollection.where("tags && ARRAY[?]::varchar[]", ["rgb++"]).count
    RgbppHourlyStatistic.upsert(
      {
        total_count: xudts_count + nft_collections_count,
        created_at_unixtimestamp: to_be_counted_date.beginning_of_day.to_i,
      },
      unique_by: :created_at_unixtimestamp,
    )
  rescue StandardError => e
    Rails.logger.error "Error occurred during GenerateRgbppHourlyStatistic error: #{e.message}"
  end

  private

  def to_be_counted_date
    last_record = UdtHourlyStatistic.order(created_at_unixtimestamp: :desc).first
    if last_record
      Time.zone.at(last_record.created_at_unixtimestamp) + 1.day
    else
      Time.current.yesterday
    end
  end
end
