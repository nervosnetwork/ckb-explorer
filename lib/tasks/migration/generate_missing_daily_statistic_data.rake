namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_missing_daily_statistic_data"
  task generate_missing_daily_statistic_data: :environment do
    current_time = Time.parse("2020-11-26")
    ended_time = Time.parse("2020-11-28")
    while current_time <= ended_time
      to_be_counted_date = current_time.beginning_of_day
      Charts::DailyStatisticGenerator.new(to_be_counted_date).call

      current_time = current_time + 1.days
    end
    puts "done"
  end
end
