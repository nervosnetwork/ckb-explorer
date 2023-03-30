module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical", backtrace: 20

    def perform(datetime = nil)
      # iterate from the creation timestamp of last daily statistic record to now day by day
      # and generate daily statistic record for each day

      last_record = ::DailyStatistic.order(created_at_unixtimestamp: :desc).first
      last_data_date = DateTime.strptime(last_record.created_at_unixtimestamp.to_s, '%s')
      puts "========= last_data_date #{last_data_date}"
      current_date = DateTime.now
      days_to_generate = (current_date - last_data_date).to_i - 1
      (1..days_to_generate).each do |i|
        date_to_generate_temp = last_data_date + i
        puts "=== i #{i} date_to_generate_temp: #{date_to_generate_temp}"
        date_to_generate = Time.at(date_to_generate_temp)
        puts "===========date_to_generate: #{date_to_generate}"
        puts "==== last_record.created_at_unixtimestamp #{Time.at last_record.created_at_unixtimestamp}"
        Charts::DailyStatisticGenerator.new(date_to_generate).call
        puts "Generating record for #{date_to_generate.strftime('%Y-%m-%d')}..."
      end

      datetime ||= Time.now
      last_record = ::DailyStatistic.order(created_at_unixtimestamp: :desc).first
      if last_record.present?
        start_date = Time.at(last_record.created_at_unixtimestamp) + 1.day
      else
        start_date = datetime - 1.day
      end
      puts "start_date: #{start_date}, datetime: #{datetime}"
      records = []
      while start_date < datetime
        ApplicationRecord.benchmark("#{start_date} generation") do
          records << Charts::DailyStatisticGenerator.new(start_date).call
        end
        start_date += 1.day
      end
      records
    end
  end
end
