namespace :migration do
  task update_unclaimed_compensations_on_daily_statistics: :environment do
    progress_bar = ProgressBar.create({
      total: DailyStatistic.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
      DailyStatistic.order(:created_at_unixtimestamp).map do |daily_statistic|
        progress_bar.increment
        to_be_counted_date = Time.at(daily_statistic.created_at_unixtimestamp)
        daily_statistic_generator = Charts::DailyStatisticGenerator.new(to_be_counted_date)

        { id: daily_statistic.id, unclaimed_compensation: daily_statistic_generator.send(:unclaimed_compensation), created_at: daily_statistic.created_at, updated_at: Time.current }
      end

    DailyStatistic.upsert_all(values)

    puts "done"
  end
end
