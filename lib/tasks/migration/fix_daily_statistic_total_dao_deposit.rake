namespace :migration do
  desc "Usage: RAILS_ENV=production bundle exec rake migration:fix_daily_statistic_total_dao_deposit"
  task fix_daily_statistic_total_dao_deposit: :environment do
    ## Delete not 16:00 UTC data
    sql = "SELECT id FROM (SELECT id, to_timestamp(CAST(created_at_unixtimestamp AS INT))::time AS time FROM daily_statistics) AS times where time != '16:00:00'"
    records = ActiveRecord::Base.connection.execute(sql)
    delete_ids = records.map { |r| r["id"] }
    DailyStatistic.where("id IN (?)", delete_ids).delete_all()
    ## Add lost date data
    from_date = Date.new(2019,11,15)
    end_date = Date.yesterday()
    should_exist_dates = (from_date..end_date).to_a.map{ |date| date.to_s }

    sql = "SELECT to_timestamp(CAST(created_at_unixtimestamp AS INT))::date AS date FROM daily_statistics"
    records = ActiveRecord::Base.connection.execute(sql)
    actual_exist_dates = records.map { |r| r["date"] }
    lost_dates = should_exist_dates - actual_exist_dates

    progress_bar = ProgressBar.create({
      total: lost_dates.count,
      format: "%e %B %p%% %c/%C"
    })
    lost_dates.each do |lost|
      progress_bar.increment
      datetime = lost.to_date().beginning_of_day()
      Charts::DailyStatisticGenerator.new(datetime, true).call()
    end

    ## refresh total_dao_deposit
    progress_bar = ProgressBar.create({
      total: DailyStatistic.count,
      format: "%e %B %p%% %c/%C"
    })

    values =
      DailyStatistic.select(:id, :created_at_unixtimestamp).order(:created_at_unixtimestamp).map do |daily_statistic|
        progress_bar.increment
        ended_at = daily_statistic.created_at_unixtimestamp.to_i * 1000
        deposit_amount = DaoEvent.processed.deposit_to_dao.created_before(ended_at).sum(:value)
        withdraw_amount = DaoEvent.processed.withdraw_from_dao.created_before(ended_at).sum(:value)
        total_dao_deposit = deposit_amount - withdraw_amount
        { id: daily_statistic.id, total_dao_deposit: total_dao_deposit }
      end
    DailyStatistic.upsert_all(values,  update_only: [:total_dao_deposit], record_timestamps: true)

    puts "done"
  end
end
