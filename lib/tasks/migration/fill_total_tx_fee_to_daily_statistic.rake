class TotalTxFeeGenerator
  include Rake::DSL
  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:generate_total_tx_fee"
      task generate_total_tx_fee: :environment do
        genesis_block_timestamp = Block.find_by(number: 0).timestamp
        genesis_block_time = Time.at(genesis_block_timestamp.to_f / 1000)
        current_time = genesis_block_time.in_time_zone
        ended_at = Time.current.yesterday
        total = ((ended_at - current_time) / 60 / 60 / 24).ceil
        progress_bar = ProgressBar.create({ total: total, format: "%e %B %p%% %c/%C" })

        while current_time <= ended_at
          to_be_counted_date = current_time.beginning_of_day
          created_at_unixtimestamp = to_be_counted_date.to_i
          started_at = time_in_milliseconds(to_be_counted_date.beginning_of_day)
          ended_at = time_in_milliseconds(to_be_counted_date.end_of_day)
          total_tx_fee = Block.created_after(started_at).created_before(ended_at).sum(:total_transaction_fee)
          DailyStatistic.find_by(created_at_unixtimestamp: created_at_unixtimestamp).update(total_tx_fee: total_tx_fee)
          current_time = current_time + 1.days
          progress_bar.increment
        end

        puts "done"
      end
    end
  end

  private

  def time_in_milliseconds(time)
    (time.to_f * 1000).floor
  end
end

TotalTxFeeGenerator.new
