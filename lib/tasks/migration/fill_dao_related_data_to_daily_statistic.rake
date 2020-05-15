class DaoRelatedDataGenerator
  include Rake::DSL
  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_dao_related_data_to_daily_statistic"
      task fill_dao_related_data_to_daily_statistic: :environment do
        genesis_block_timestamp = Block.find_by(number: 0).timestamp
        genesis_block_time = Time.at(genesis_block_timestamp.to_f / 1000)
        current_time = genesis_block_time.in_time_zone
        ended_time = Time.current.yesterday
        total = ((ended_time - current_time) / 60 / 60 / 24).ceil
        progress_bar = ProgressBar.create({ total: total, format: "%e %B %p%% %c/%C" })

        values = []
        while current_time <= ended_time
          to_be_counted_date = current_time.beginning_of_day
          created_at_unixtimestamp = to_be_counted_date.to_i
          daily_statistic = DailyStatistic.find_by(created_at_unixtimestamp: created_at_unixtimestamp)
          daily_statistic_generator = Charts::DailyStatisticGenerator.new(to_be_counted_date)
          daily_dao_deposit = daily_statistic_generator.send(:daily_dao_deposit)
          daily_dao_depositors_count = daily_statistic_generator.send(:daily_dao_depositors_count)
          daily_dao_withdraw = daily_statistic_generator.send(:daily_dao_withdraw)
          values << { id: daily_statistic.id, daily_dao_deposit: daily_dao_deposit, daily_dao_depositors_count: daily_dao_depositors_count, daily_dao_withdraw: daily_dao_withdraw, created_at: daily_statistic.created_at, updated_at: Time.current }
          current_time = current_time + 1.days
          progress_bar.increment
        end

        DailyStatistic.upsert_all(values)

        puts "done"
      end
    end
  end
end

DaoRelatedDataGenerator.new
