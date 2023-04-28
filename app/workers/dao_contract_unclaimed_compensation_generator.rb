class DaoContractUnclaimedCompensationGenerator
  include Sidekiq::Worker

  def perform
    DaoContract.default_contract.update(unclaimed_compensation: cal_unclaimed_compensation)
  end

  private

  # @return [Integer]
  def cal_unclaimed_compensation
    phase1_dao_interests + unmade_dao_interests
  end

  # @return [Integer]
  def phase1_dao_interests
    total = 0
    CellOutput.nervos_dao_withdrawing.live.find_each do |nervos_dao_withdrawing_cell|
      total += CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
    end
    total
  end

  # @return [Integer]
  def unmade_dao_interests
    tip_dao = current_tip_block.dao
    total = 0
    CellOutput.nervos_dao_deposit.live.find_each do |cell_output|
      total += DaoCompensationCalculator.new(cell_output, tip_dao).call
    end
    total
  end

  def ended_at
    @ended_at ||= CkbUtils.time_in_milliseconds(Time.current)
  end

  def current_tip_block
    Block.recent.first
  end
end
