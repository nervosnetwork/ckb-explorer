namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:update_daily_statistic_interests_related_info"
  task update_daily_statistic_interests_related_info: :environment do
    progress_bar = ProgressBar.create({ total: DailyStatistic.count, format: "%e %B %p%% %c/%C" })

    values = []
    DailyStatistic.all.each do |daily_statistic|
      to_be_counted_date = Time.at(daily_statistic.created_at_unixtimestamp)
      daily_statistic_generator = Charts::DailyStatisticGenerator.new(to_be_counted_date)
      unclaimed_compensation = daily_statistic_generator.send(:unclaimed_compensation)
      treasury_amount = daily_statistic_generator.send(:treasury_amount)
      deposit_compensation = unclaimed_compensation + daily_statistic_generator.send(:claimed_compensation)
      total_supply = daily_statistic_generator.send(:total_supply)
      values << { id: daily_statistic.id, created_at: daily_statistic.created_at,
                  updated_at: Time.current, unclaimed_compensation: unclaimed_compensation, treasury_amount: treasury_amount,
                  deposit_compensation: deposit_compensation, total_supply: total_supply }

      progress_bar.increment
    end

    DailyStatistic.upsert_all(values)

    puts "done"
  end
end
