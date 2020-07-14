class DaoContractUnclaimedCompensationGenerator
  include Sidekiq::Worker

  def perform
    DaoContract.default_contract.update(unclaimed_compensation: cal_unclaimed_compensation)
  end

  private

  def cal_unclaimed_compensation
    phase1_dao_interests + unmade_dao_interests
  end

  def phase1_dao_interests
    CellOutput.nervos_dao_withdrawing.live.reduce(0) do |memo, nervos_dao_withdrawing_cell|
      memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
    end
  end

  def unmade_dao_interests
    tip_dao = current_tip_block.dao
    CellOutput.nervos_dao_deposit.live.reduce(0) do |memo, cell_output|
      memo + DaoCompensationCalculator.new(cell_output, tip_dao).call
    end
  end

  def ended_at
    @ended_at ||= CkbUtils.time_in_milliseconds(Time.current)
  end

  def current_tip_block
    Block.recent.first
  end
end
