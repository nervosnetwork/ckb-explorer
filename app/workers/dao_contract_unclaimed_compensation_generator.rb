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
    CellOutput.nervos_dao_withdrawing.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
      memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
    end
  end

  def unmade_dao_interests
    CellOutput.nervos_dao_deposit.generated_before(ended_at).unconsumed_at(ended_at).reduce(0) do |memo, cell_output|
      dao = cell_output.block.dao
      tip_dao = current_tip_block.dao
      parse_dao = CkbUtils.parse_dao(dao)
      tip_parse_dao = CkbUtils.parse_dao(tip_dao)
      memo + (cell_output.capacity * tip_parse_dao.ar_i / parse_dao.ar_i) - cell_output.capacity
    end
  end

  def ended_at
    @ended_at ||= CkbUtils.time_in_milliseconds(Time.current)
  end

  def current_tip_block
    Block.recent.first
  end
end
