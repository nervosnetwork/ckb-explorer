module Charts
  class DailyStatisticGenerator
    MILLISECONDS_IN_DAY = BigDecimal(24 * 60 * 60 * 1000)
    GENESIS_TIMESTAMP = 1573852190812

    def initialize(datetime = nil, from_scratch = false)
      raise "datetime must be a Time" if datetime.present? && !datetime.is_a?(Time)

      @datetime = datetime
      @from_scratch = from_scratch
    end

    def call
      daily_ckb_transactions_count = CkbTransaction.created_after(started_at).created_before(ended_at).count
      return if daily_ckb_transactions_count.zero?

      mining_reward = Block.where("timestamp <= ?", ended_at).sum(:secondary_reward)
      deposit_compensation = unclaimed_compensation + claimed_compensation
      estimated_apc = DaoContract.default_contract.estimated_apc(current_tip_block.fraction_epoch)
      block_timestamp = Block.created_after(started_at).created_before(ended_at).recent.pick(:timestamp)
      addresses_count = processed_addresses_count
      daily_statistic = ::DailyStatistic.find_or_create_by!(created_at_unixtimestamp: to_be_counted_date.to_i)
      daily_statistic.update(block_timestamp: block_timestamp, transactions_count: daily_ckb_transactions_count,
                             addresses_count: addresses_count, total_dao_deposit: total_dao_deposit,
                             dao_depositors_count: dao_depositors_count, unclaimed_compensation: unclaimed_compensation,
                             claimed_compensation: claimed_compensation, average_deposit_time: average_deposit_time,
                             mining_reward: mining_reward, deposit_compensation: deposit_compensation, treasury_amount: treasury_amount,
                             estimated_apc: estimated_apc, live_cells_count: live_cells_count, dead_cells_count: dead_cells_count, avg_hash_rate: avg_hash_rate,
                             avg_difficulty: avg_difficulty, uncle_rate: uncle_rate, total_depositors_count: total_depositors_count,
                             address_balance_distribution: address_balance_distribution, total_tx_fee: total_tx_fee, occupied_capacity: occupied_capacity,
                             daily_dao_deposit: daily_dao_deposit, daily_dao_depositors_count: daily_dao_depositors_count, daily_dao_withdraw: daily_dao_withdraw,
                             total_supply: total_supply, circulating_supply: circulating_supply, circulation_ratio: circulation_ratio, block_time_distribution: block_time_distribution,
                             epoch_time_distribution: epoch_time_distribution, epoch_length_distribution: epoch_length_distribution, average_block_time: average_block_time)
    end

    private

    attr_reader :datetime, :from_scratch

    def average_block_time
      Block.connection.select_all(avg_block_time_rolling_by_hour_sql).to_a.map do |item|
        { timestamp: item["stat_timestamp"].to_i, avg_block_time_daily: item["avg_bt1"], avg_block_time_weekly: item["avg_bt2"] }
      end
    end

    def avg_block_time_rolling_by_hour_sql
      <<-SQL
        with avg_block_time_24_hours_rolling_by_hour as (
          select stat_timestamp,
          avg(avg_block_time_per_hour) over(order by stat_timestamp rows between 24 preceding and current row) as avg_bt,
          avg(avg_block_time_per_hour) over(order by stat_timestamp rows between 7 * 24 preceding and current row) as avg_bt1
          from block_time_statistics
        )
        select stat_timestamp, round(avg_bt, 2) avg_bt1, round(avg_bt1, 2) avg_bt2 from avg_block_time_24_hours_rolling_by_hour where stat_timestamp >= #{35.days.ago.to_i} order by stat_timestamp limit 720
      SQL
    end

    def epoch_length_distribution
      max_n = 1700
      ranges = (700..max_n).step(100).map { |n| [n, n + 100] }
      tip_epoch_number = current_tip_block.epoch
      interval = 499
      start_epoch_number = [0, tip_epoch_number - interval].max

      ranges.each_with_index.map { |range, index|
        epoch_count = ::EpochStatistic.where("epoch_number >= ? and epoch_number <= ?", start_epoch_number, tip_epoch_number).where("epoch_length > ? and epoch_length <= ?", range[0], range[1]).count

        [range[1], epoch_count]
      }.compact
    end

    def epoch_time_distribution
      max_n = 119
      ranges = [[0, 180]] + (180..(180 + max_n)).map { |n| [n, n + 1] }
      ranges.each_with_index.map { |range, index|
        milliseconds_start = range[0] * 60 * 1000
        milliseconds_end = range[1] * 60 * 1000
        if index.zero?
          epoch_count = ::EpochStatistic.where("epoch_time > 0 and epoch_time <= ?", milliseconds_end).count
        elsif index == max_n + 1
          epoch_count = ::EpochStatistic.where("epoch_time > ?", milliseconds_start).count
        else
          epoch_count = ::EpochStatistic.where("epoch_time > ? and epoch_time <= ?", milliseconds_start, milliseconds_end).count
        end

        [range[1], epoch_count]
      }.compact
    end

    def block_time_distribution
      step = 0.1
      max_n = 50 - step
      ranges = (0..max_n).step(0.1).map { |n| [n.round(2), (n + step).round(2)] }
      tip_block_number = current_tip_block.number
      interval = 49999
      start_block_number = [0, tip_block_number - interval].max

      ranges.map do |range|
        millisecond_start = range[0] * 1000
        millisecond_end = range[1] * 1000
        block_count = Block.where("number >= ? and number <= ?", start_block_number, tip_block_number).where("block_time > ? and block_time <= ?", millisecond_start, millisecond_end).count
        [range[1], block_count]
      end
    end

    def circulating_supply
      MarketData.new("circulating_supply", current_tip_block.number).call
    end

    def circulation_ratio
      total_dao_deposit / 10**8 / circulating_supply
    end

    def total_supply
      tip_dao = current_tip_block.dao
      tip_parse_dao = CkbUtils.parse_dao(tip_dao)
      tip_parse_dao.c_i - MarketData::BURN_QUOTA - treasury_amount
    end

    def daily_dao_deposit
      @daily_dao_deposit ||= DaoEvent.processed.deposit_to_dao.created_after(started_at).created_before(ended_at).sum(:value)
    end

    def daily_dao_depositors_count
      @daily_dao_depositors_count ||= DaoEvent.processed.new_dao_depositor.created_after(started_at).created_before(ended_at).count
    end

    def daily_dao_withdraw
      @daily_dao_withdraw ||= DaoEvent.processed.withdraw_from_dao.created_after(started_at).created_before(ended_at).sum(:value)
    end

    def occupied_capacity
      CellOutput.generated_before(ended_at).unconsumed_at(ended_at).sum(:occupied_capacity)
    end

    def address_balance_distribution
      max_n = 9
      ranges =
        (1..max_n).map do |n|
          if n == 1
            [0, 100]
          else
            [10**n, 10**(n + 1)]
          end
        end

      ranges.each_with_index.map do |range, index|
        begin_value = range[0] * 10**8
        end_value = range[1] * 10**8
        if index == max_n - 1
          addresses_count = Address.visible.where("balance > ?", begin_value).count
          total_addresses_count = Address.visible.where("balance > 0").count
        else
          addresses_count = Address.visible.where("balance > ? and balance <= ?", begin_value, end_value).count
          total_addresses_count = Address.visible.where("balance > 0 and balance <= ?", end_value).count
        end

        [range[1], addresses_count, total_addresses_count]
      end
    end

    def total_tx_fee
      Block.created_after(started_at).created_before(ended_at).sum(:total_transaction_fee)
    end

    def live_cells_count
      if from_scratch
        CellOutput.generated_before(ended_at).unconsumed_at(ended_at).count
      else
        CellOutput.generated_after(started_at).generated_before(ended_at).count + yesterday_daily_statistic.live_cells_count.to_i - dead_cells_count_today
      end
    end

    def dead_cells_count_today
      @dead_cells_count_today ||= CellOutput.consumed_after(started_at).consumed_before(ended_at).count
    end

    def dead_cells_count
      if from_scratch
        CellOutput.generated_before(ended_at).consumed_before(ended_at).count
      else
        dead_cells_count_today + yesterday_daily_statistic.dead_cells_count.to_i
      end
    end

    def total_blocks_count
      @total_blocks_count ||= Block.created_after(started_at).created_before(ended_at).count
    end

    def epoch_numbers_for_the_day
      Block.created_after(started_at).created_before(ended_at).distinct(:epoch).pluck(:epoch)
    end

    def avg_hash_rate
      first_block_for_the_day = Block.created_after(started_at).created_before(ended_at).recent.last
      last_block_for_the_day = Block.created_after(started_at).created_before(ended_at).recent.first
      total_block_time = last_block_for_the_day.timestamp - first_block_for_the_day.timestamp

      BigDecimal(total_difficulties_for_the_day) / total_block_time
    end

    def avg_difficulty
      BigDecimal(total_difficulties_for_the_day) / total_blocks_count
    end

    def total_difficulties_for_the_day
      @total_difficulties ||=
        epoch_numbers_for_the_day.reduce(0) do |memo, epoch_number|
          first_block_of_the_epoch = Block.created_after(started_at).created_before(ended_at).where(epoch: epoch_number).recent.last
          last_block_of_the_epoch = Block.created_after(started_at).created_before(ended_at).where(epoch: epoch_number).recent.first
          memo + first_block_of_the_epoch.difficulty * (last_block_of_the_epoch.number - first_block_of_the_epoch.number + 1)
        end
    end

    def uncle_rate
      uncles_count = Block.created_after(started_at).created_before(ended_at).sum(:uncles_count)
      BigDecimal(uncles_count) / total_blocks_count
    end

    def processed_addresses_count
      if from_scratch
        Address.created_before(ended_at).count
      else
        Address.created_after(started_at).created_before(ended_at).count + yesterday_daily_statistic.addresses_count.to_i
      end
    end

    def current_tip_block
      @current_tip_block ||=
        begin
          if from_scratch
            Block.created_before(ended_at).recent.first
          else
            Block.created_after(started_at).created_before(ended_at).recent.first
          end
        end
    end

    def total_dao_deposit
      if from_scratch
        deposit_amount = DaoEvent.processed.deposit_to_dao.created_before(ended_at).sum(:value)
        withdraw_amount = DaoEvent.processed.withdraw_from_dao.created_before(ended_at).sum(:value)
        deposit_amount - withdraw_amount
      else
        daily_dao_deposit - daily_dao_withdraw + yesterday_daily_statistic.total_dao_deposit.to_i
      end
    end

    def dao_depositors_count
      if from_scratch
        total_depositors_count - DaoEvent.processed.take_away_all_deposit.created_before(ended_at).count
      else
        withdrawals_today = DaoEvent.processed.take_away_all_deposit.created_after(started_at).created_before(ended_at).count
        daily_dao_depositors_count - withdrawals_today + yesterday_daily_statistic.dao_depositors_count.to_i
      end
    end

    def total_depositors_count
      @total_depositors_count ||=
        begin
          if from_scratch
            DaoEvent.processed.new_dao_depositor.created_before(ended_at).count
          else
            new_depositors_count_today = DaoEvent.processed.new_dao_depositor.created_after(started_at).created_before(ended_at).count
            new_depositors_count_today + yesterday_daily_statistic.total_depositors_count.to_i
          end
        end
    end

    def to_be_counted_date
      @to_be_counted_date ||= datetime.presence || Time.current.yesterday.beginning_of_day
    end

    def started_at
      @started_at ||= CkbUtils.time_in_milliseconds(to_be_counted_date.beginning_of_day)
    end

    def ended_at
      @ended_at ||= CkbUtils.time_in_milliseconds(to_be_counted_date.end_of_day) - 1
    end

    def unclaimed_compensation
      @unclaimed_compensation ||=
        begin
          phase1_dao_interests + unmade_dao_interests
        end
    end

    def claimed_compensation
      @claimed_compensation ||=
        begin
          if from_scratch
            CellOutput.nervos_dao_withdrawing.consumed_before(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
              memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
            end
          else
            claimed_compensation_today =
              CellOutput.nervos_dao_withdrawing.consumed_after(started_at).consumed_before(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
                memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
              end

            claimed_compensation_today + yesterday_daily_statistic.claimed_compensation.to_i
          end
        end
    end

    def phase1_dao_interests
      CellOutput.nervos_dao_withdrawing.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
        memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
      end
    end

    def unmade_dao_interests
      @unmade_dao_interests ||=
        begin
          CellOutput.nervos_dao_deposit.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, cell_output|
            dao = cell_output.block.dao
            tip_dao = current_tip_block.dao
            parse_dao = CkbUtils.parse_dao(dao)
            tip_parse_dao = CkbUtils.parse_dao(tip_dao)
            memo + (cell_output.capacity * tip_parse_dao.ar_i / parse_dao.ar_i) - cell_output.capacity
          end
        end
    end

    def average_deposit_time
      interest_bearing_deposits = 0
      uninterest_bearing_deposits = 0
      sum_interest_bearing =
        CellOutput.nervos_dao_withdrawing.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
          nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
          nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
          interest_bearing_deposits += nervos_dao_deposit_cell.capacity
          memo + nervos_dao_deposit_cell.capacity * (nervos_dao_withdrawing_cell.block_timestamp - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
        end
      sum_uninterest_bearing =
        CellOutput.nervos_dao_deposit.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_deposit_cell|
          uninterest_bearing_deposits += nervos_dao_deposit_cell.capacity

          memo + nervos_dao_deposit_cell.capacity * (ended_at - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
        end

      total_deposits = interest_bearing_deposits + uninterest_bearing_deposits
      return 0 if total_deposits.zero?

      (sum_interest_bearing + sum_uninterest_bearing) / total_deposits
    end

    def treasury_amount
      @treasury_amount ||=
        begin
          parse_dao = CkbUtils.parse_dao(current_tip_block.dao)
          parse_dao.s_i - unmade_dao_interests
        end
    end

    def yesterday_daily_statistic
      @yesterday_daily_statistic ||=
        begin
          yesterday_statistic = ::DailyStatistic.find_by(created_at_unixtimestamp: to_be_counted_date.yesterday.beginning_of_day.to_i)
          if to_be_counted_date.beginning_of_day.to_i == Time.at(GENESIS_TIMESTAMP / 1000).in_time_zone.beginning_of_day.to_i || aggron_first_day?
            OpenStruct.new(addresses_count: 0, total_dao_deposit: 0, dao_depositors_count: 0, unclaimed_compensation: 0, claimed_compensation: 0, average_deposit_time: 0, mining_reward: 0, deposit_compensation: 0, treasury_amount: 0, total_depositors_count: 0, live_cells_count: 0, dead_cells_count: 0, occupied_capacity: 0)
          else
            yesterday_statistic
          end
        end
    end

    def aggron_first_day?
      genesis_block_timestamp = Block.find_by(number: 0).timestamp

      ENV["CKB_NET_MODE"] == "testnet" && to_be_counted_date.beginning_of_day.to_i == Time.at(genesis_block_timestamp / 1000).in_time_zone.beginning_of_day.to_i
    end
  end
end
