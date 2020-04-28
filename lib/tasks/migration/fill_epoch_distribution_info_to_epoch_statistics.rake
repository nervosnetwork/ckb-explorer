class EpochDistributionInfoGenerator
  include Rake::DSL

  def initialize
    namespace :migration do
      desc "Usage: RAILS_ENV=production bundle exec rake migration:fill_epoch_distribution_info"
      task fill_epoch_distribution_info: :environment do
        latest_epoch_statistic = EpochStatistic.order(epoch_number: :desc)[0]
        epoch_statistic_generator = Charts::EpochStatisticGenerator.new(latest_epoch_statistic.epoch_number)

        epoch_time_distribution = epoch_statistic_generator.send(:epoch_time_distribution)
        epoch_length_distribution = epoch_statistic_generator.send(:epoch_length_distribution)

        latest_epoch_statistic.update(epoch_time_distribution: epoch_time_distribution, epoch_length_distribution: epoch_length_distribution)
        puts "done"
      end
    end
  end

  private

end

EpochDistributionInfoGenerator.new
