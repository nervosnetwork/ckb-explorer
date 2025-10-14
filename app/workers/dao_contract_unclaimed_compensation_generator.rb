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
    events = DaoEvent.processed.where(event_type: "withdraw_from_dao", consumed_transaction_id: nil)

    pairs = events.map{|e| [e.ckb_transaction_id, e.cell_index] }
    conditions = pairs.map do |tx_id, cell_idx|
      ["ckb_transaction_id = #{tx_id} AND cell_index = #{cell_idx}"]
    end
    query = conditions.map do |cond|
      "(#{cond[0]})"
    end.join(" OR ")
    cells = CellOutput.where(query).to_a

    cells.each do |nervos_dao_withdrawing_cell|
      total += CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
    end
    total
  end

  # @return [Integer]
  def unmade_dao_interests
    tip_dao = current_tip_block.dao
    total = 0
    DaoEvent.depositor.includes(:cell_output).select(:cell_output_id, :id).find_each do |event|
      total += DaoCompensationCalculator.new(event.cell_output, tip_dao).call
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
