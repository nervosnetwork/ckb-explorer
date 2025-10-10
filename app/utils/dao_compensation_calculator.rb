class DaoCompensationCalculator
  attr_reader :deposit_cell_output, :withdraw_block_dao, :withdraw_cell_output, :deposit_dao

  def initialize(deposit_cell_output, withdraw_block_dao, withdraw_cell_output = nil, deposit_dao = nil)
    @deposit_cell_output = deposit_cell_output
    @withdraw_cell_output = withdraw_cell_output
    @withdraw_block_dao = withdraw_block_dao
    @deposit_dao = deposit_dao
  end

  def call
    compensation_generating_capacity * parsed_withdraw_block_dao.ar_i / parsed_deposit_block_dao.ar_i - compensation_generating_capacity
  end

  private

  def parsed_withdraw_block_dao
    CkbUtils.parse_dao(withdraw_block_dao)
  end

  def parsed_deposit_block_dao
    if deposit_cell_output
      CkbUtils.parse_dao(deposit_cell_output.dao)
    else
      CkbUtils.parse_dao(deposit_dao)
    end
  end

  def compensation_generating_capacity
    cell_output = withdraw_cell_output.presence || deposit_cell_output
    @compensation_generating_capacity ||= (cell_output.capacity - cell_output.occupied_capacity).to_i
  end
end
