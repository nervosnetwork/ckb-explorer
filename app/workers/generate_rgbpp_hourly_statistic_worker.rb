class GenerateRgbppHourlyStatisticWorker
  include Sidekiq::Job

  def perform
    xudt_count = Udt.published_xudt.joins(:xudt_tag).where("xudt_tags.tags && ARRAY[?]::varchar[]", ["rgb++"]).count
    dob_count = TokenCollection.where("tags && ARRAY[?]::varchar[]", ["rgb++"]).count
    created_at_unixtimestamp = to_be_counted_date.beginning_of_day.to_i
    RgbppHourlyStatistic.upsert(
      { xudt_count:, dob_count:, created_at_unixtimestamp: },
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
