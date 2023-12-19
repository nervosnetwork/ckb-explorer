module Charts
  class CkbHodlWavesStatistic
    include Sidekiq::Worker
    sidekiq_options queue: "critical"

    def perform
      over_three_years = CellOutput.live.generated_before(3.years.ago.to_i * 1000).sum(:capacity)
      one_year_to_three_years = CellOutput.live.generated_between(
        3.years.ago.to_i * 1000, 1.year.ago.to_i * 1000
      ).sum(:capacity)
      six_months_to_one_year = CellOutput.live.generated_between(
        1.year.ago.to_i * 1000, 6.months.ago.to_i * 1000
      ).sum(:capacity)
      three_months_to_six_months = CellOutput.live.generated_between(
        6.months.ago.to_i * 1000, 3.months.ago.to_i * 1000
      ).sum(:capacity)
      one_month_to_three_months = CellOutput.live.generated_between(
        3.months.ago.to_i * 1000, 1.month.ago.to_i * 1000
      ).sum(:capacity)
      one_week_to_one_month = CellOutput.live.generated_between(
        1.month.ago.to_i * 1000, 1.week.ago.to_i * 1000
      ).sum(:capacity)
      day_to_one_week = CellOutput.live.generated_between(
        1.week.ago.to_i * 1000, 1.day.ago.to_i * 1000
      ).sum(:capacity)
      latest_day = CellOutput.live.generated_between(
        1.day.ago.beginning_of_day.to_i * 1000, 1.day.ago.end_of_day.to_i * 1000
      ).sum(:capacity)

      info = {
        total_supply: MarketData.new.indicators_json["total_supply"],
        updated_at: Time.current.to_i,
      }

      ckb = {
        over_three_years:,
        one_year_to_three_years:,
        six_months_to_one_year:,
        three_months_to_six_months:,
        one_month_to_three_months:,
        one_week_to_one_month:,
        day_to_one_week:,
        latest_day:,
      }.transform_values { |value| (value / 10**8).truncate(8) }

      StatisticInfo.first.update(ckb_hodl_waves: ckb.merge!(info))
    end
  end
end
