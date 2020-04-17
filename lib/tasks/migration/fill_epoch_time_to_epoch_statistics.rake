class EpochTimeGenerator
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_epoch_time_to_epoch_statistics"
      task fill_epoch_time_to_epoch_statistics: :environment do
        max_epoch_number = Block.maximum(:epoch)
        progress_bar = ProgressBar.create({
          total: max_epoch_number + 1,
          format: "%e %B %p%% %c/%C"
        })

        values =
          (0...max_epoch_number).map do |epoch_number|
            first_block_in_epoch = Block.where(epoch: epoch_number).order(:number).select(:timestamp)[0]
            last_lock_in_epoch = Block.where(epoch: epoch_number).order(number: :desc).select(:timestamp)[0]
            epoch_time = last_lock_in_epoch.timestamp - first_block_in_epoch.timestamp
            progress_bar.increment
            epoch_statistic = EpochStatistic.find_by(epoch_number: epoch_number)

            { epoch_number: epoch_number, epoch_time: epoch_time, created_at: epoch_statistic.created_at, updated_at: Time.current }
          end

        EpochStatistic.upsert_all(values, unique_by: :epoch_number)

        puts "done"
      end
    end
  end

  private

end

EpochTimeGenerator.new
