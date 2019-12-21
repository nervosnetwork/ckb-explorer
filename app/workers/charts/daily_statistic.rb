module Charts
  class DailyStatistic
    include Sidekiq::Worker
    sidekiq_options unique: :until_executed
    sidekiq_options retry: false
    sidekiq_options queue: "critical"

    MILLISECONDS_IN_DAY = BigDecimal(24 * 60 * 60 * 1000)

    def perform(datetime = nil)
      to_be_counted_date = datetime.presence || DateTime.now - 1.day
      started_at = to_be_counted_date.beginning_of_day.strftime("%Q")
      ended_at = to_be_counted_date.end_of_day.strftime("%Q")
      daily_ckb_transactions_count = CkbTransaction.where("block_timestamp >= ? and block_timestamp <= ?", started_at, ended_at).count
      addresses_count = Address.where("block_timestamp <= ?", ended_at).count
      deposit_cells = CellOutput.where(cell_type: "nervos_dao_deposit").where("block_timestamp <= ?", ended_at)
      total_dao_deposit = datetime.blank? ? deposit_cells.where(status: "live").sum(:capacity) : deposit_cells.sum(:capacity)
      dao_depositors_count = DaoEvent.processed.where("block_timestamp <= ?", ended_at).count
      cell_outputs = CellOutput.where("block_timestamp <= ?", ended_at)
      current_tip_block = Block.where("timestamp <= ?", ended_at).recent.first
      mining_reward = Block.where("timestamp <= ?", ended_at).sum(:secondary_reward)
      deposit_compensation = unclaimed_compensation(cell_outputs, current_tip_block) + claimed_compensation(cell_outputs)
      estimated_apc = DaoContract.default_contract.estimated_apc(current_tip_block.fraction_epoch)
      block_timestamp = Block.created_after(started_at).created_before(ended_at).recent.pick(:timestamp)
      daily_statistic = ::DailyStatistic.create_or_find_by!(block_timestamp: block_timestamp)
      daily_statistic.update(created_at_unixtimestamp: to_be_counted_date.to_i, transactions_count: daily_ckb_transactions_count,
                             addresses_count: addresses_count, total_dao_deposit: total_dao_deposit,
                             dao_depositors_count: dao_depositors_count, unclaimed_compensation: unclaimed_compensation(cell_outputs, current_tip_block),
                             claimed_compensation: claimed_compensation(cell_outputs), average_deposit_time: average_deposit_time(cell_outputs),
                             mining_reward: mining_reward, deposit_compensation: deposit_compensation, treasury_amount: treasury_amount(cell_outputs, current_tip_block),
                             estimated_apc: estimated_apc)
    end

    private

    def unclaimed_compensation(cell_outputs, current_tip_block)
      @unclaimed_compensation ||=
        begin
          phase1_dao_interests(cell_outputs) + unmade_dao_interests(cell_outputs, current_tip_block)
        end
    end

    def claimed_compensation(cell_outputs)
      @claimed_compensation ||=
        begin
          cell_outputs.nervos_dao_withdrawing.dead.reduce(0) do |memo, nervos_dao_withdrawing_cell|
            memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
          end
        end
    end

    def phase1_dao_interests(cell_outputs)
      cell_outputs.nervos_dao_withdrawing.live.reduce(0) do |memo, nervos_dao_withdrawing_cell|
        memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
      end
    end

    def unmade_dao_interests(cell_outputs, current_tip_block)
      @unmade_dao_interests ||=
        begin
          cell_outputs.nervos_dao_deposit.live.reduce(0) do |memo, cell_output|
            dao = cell_output.block.dao
            tip_dao = current_tip_block.dao
            parse_dao = CkbUtils.parse_dao(dao)
            tip_parse_dao = CkbUtils.parse_dao(tip_dao)
            memo + cell_output.capacity * tip_parse_dao.ar_i / parse_dao.ar_i
          end
        end
    end

    def average_deposit_time(cell_outputs)
      interest_bearing_deposits = 0
      uninterest_bearing_deposits = 0
      sum_interest_bearing = cell_outputs.nervos_dao_withdrawing.live.reduce(0) do |memo, nervos_dao_withdrawing_cell|
        nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.generated_by
        nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
        interest_bearing_deposits += nervos_dao_deposit_cell.capacity
        memo + nervos_dao_deposit_cell.capacity * (nervos_dao_withdrawing_cell.block_timestamp - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
      end
      sum_uninterest_bearing = cell_outputs.nervos_dao_deposit.live.reduce(0) do |memo, nervos_dao_deposit_cell|
        current_time = DateTime.now.strftime("%Q").to_i
        uninterest_bearing_deposits += nervos_dao_deposit_cell.capacity

        memo + nervos_dao_deposit_cell.capacity * (current_time - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
      end

      (sum_interest_bearing + sum_uninterest_bearing) / (interest_bearing_deposits + uninterest_bearing_deposits)
    end

    def treasury_amount(cell_outputs, current_tip_block)
      parse_dao = CkbUtils.parse_dao(current_tip_block.dao)
      parse_dao.s_i - unmade_dao_interests(cell_outputs, current_tip_block)
    end
  end
end
