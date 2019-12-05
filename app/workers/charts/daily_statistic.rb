module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    def perform(datetime = nil)
      to_be_counted_date = datetime.presence || DateTime.now - 1.day
      started_at = to_be_counted_date.beginning_of_day.strftime("%Q")
      ended_at = to_be_counted_date.end_of_day.strftime("%Q")
      daily_ckb_transactions_count = CkbTransaction.where("block_timestamp >= ? and block_timestamp <= ?", started_at, ended_at).count
      addresses_count = Address.where("block_timestamp <= ?", ended_at).count
      deposit_cells = CellOutput.where(cell_type: "nervos_dao_deposit").where("block_timestamp <= ?", ended_at)
      total_dao_deposit = datetime.blank? ? deposit_cells.where(status: "live").sum(:capacity) : deposit_cells.sum(:capacity)
      doc/api.raml
      block_timestamp = Block.created_after(started_at).created_before(ended_at).recent.pick(:timestamp)
      daily_statistic = ::DailyStatistic.create_or_find_by!(block_timestamp: block_timestamp)
      daily_statistic.update(created_at_unixtimestamp: to_be_counted_date.to_i, transactions_count: daily_ckb_transactions_count,
                             addresses_count: addresses_count, total_dao_deposit: total_dao_deposit)
    end
  end
end
