module Charts
  class DailyStatisticGenerator
    MILLISECONDS_IN_DAY = BigDecimal(24 * 60 * 60 * 1000)

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
                             avg_difficulty: avg_difficulty, uncle_rate: uncle_rate, total_depositors_count: total_depositors_count)
    end

    private

    attr_reader :datetime, :from_scratch

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
        deposit_amount_today = DaoEvent.processed.deposit_to_dao.created_after(started_at).created_before(ended_at).sum(:value)
        withdraw_amount_today = DaoEvent.processed.withdraw_from_dao.created_after(started_at).created_before(ended_at).sum(:value)
        deposit_amount_today - withdraw_amount_today + yesterday_daily_statistic.total_dao_deposit.to_i
      end
    end

    def dao_depositors_count
      if from_scratch
        total_depositors_count - DaoEvent.processed.take_away_all_deposit.created_before(ended_at).count
      else
        withdrawals_today =  DaoEvent.processed.take_away_all_deposit.created_after(started_at).created_before(ended_at).count
        new_depositors_today = DaoEvent.processed.new_dao_depositor.created_after(started_at).created_before(ended_at).count
        new_depositors_today - withdrawals_today + yesterday_daily_statistic.dao_depositors_count.to_i
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
      @started_at ||= time_in_milliseconds(to_be_counted_date.beginning_of_day)
    end

    def ended_at
      @ended_at ||= time_in_milliseconds(to_be_counted_date.end_of_day) - 1
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
      sum_interest_bearing = CellOutput.nervos_dao_withdrawing.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
        nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
        nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
        interest_bearing_deposits += nervos_dao_deposit_cell.capacity
        memo + nervos_dao_deposit_cell.capacity * (nervos_dao_withdrawing_cell.block_timestamp - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
      end
      sum_uninterest_bearing = CellOutput.nervos_dao_deposit.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_deposit_cell|
        uninterest_bearing_deposits += nervos_dao_deposit_cell.capacity

        memo + nervos_dao_deposit_cell.capacity * (ended_at - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
      end

      (sum_interest_bearing + sum_uninterest_bearing) / (interest_bearing_deposits + uninterest_bearing_deposits)
    end

    def treasury_amount
      parse_dao = CkbUtils.parse_dao(current_tip_block.dao)
      parse_dao.s_i - unmade_dao_interests
    end

    def time_in_milliseconds(time)
      (time.to_f * 1000).floor
    end

    def yesterday_daily_statistic
      @yesterday_daily_statistic ||= ::DailyStatistic.find_by(created_at_unixtimestamp: to_be_counted_date.yesterday.beginning_of_day.to_i) || OpenStruct.new(addresses_count: 0, total_dao_deposit: 0, dao_depositors_count: 0, unclaimed_compensation: 0, claimed_compensation: 0, average_deposit_time: 0, mining_reward: 0, deposit_compensation: 0, treasury_amount: 0, total_depositors_count: 0, live_cells_count: 0, dead_cells_count: 0)
    end
  end
end
