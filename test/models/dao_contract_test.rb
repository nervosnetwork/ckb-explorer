require "test_helper"

class DaoContractTest < ActiveSupport::TestCase
  context "validations" do
    should validate_presence_of(:total_deposit)
    should validate_numericality_of(:total_deposit).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:claimed_compensation)
    should validate_numericality_of(:claimed_compensation).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:deposit_transactions_count)
    should validate_numericality_of(:deposit_transactions_count).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:withdraw_transactions_count)
    should validate_numericality_of(:withdraw_transactions_count).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:depositors_count)
    should validate_numericality_of(:depositors_count).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:total_depositors_count)
    should validate_numericality_of(:total_depositors_count).
      is_greater_than_or_equal_to(0)
  end

  test "should have correct columns" do
    dao_contract = create(:dao_contract)
    expected_attributes = %w(
      created_at deposit_transactions_count depositors_count id claimed_compensation
      total_deposit total_depositors_count updated_at withdraw_transactions_count unclaimed_compensation ckb_transactions_count
    )
    assert_equal expected_attributes.sort, dao_contract.attributes.keys.sort
  end

  test "estimated apc when deposit period is less than one year" do
    dao_contract = DaoContract.default_contract
    expected_estimated_apc = 3.7
    deposit_epoch = OpenStruct.new(number: 0, index: 0, length: 1800)
    assert_equal expected_estimated_apc, dao_contract.estimated_apc(deposit_epoch, 2190 * 0.19).round(2)
  end

  test "estimated apc when deposit period is one year cross period" do
    dao_contract = DaoContract.default_contract
    expected_estimated_apc = 2.44
    deposit_epoch = OpenStruct.new(number: 2190 * 3.5, index: 0, length: 1800)

    assert_equal expected_estimated_apc, dao_contract.estimated_apc(deposit_epoch).round(2)
  end

  test "estimated apc when deposit period is more than four year" do
    dao_contract = DaoContract.default_contract
    expected_estimated_apc = 2.94
    deposit_epoch = OpenStruct.new(number: 0, index: 0, length: 1800)

    assert_equal expected_estimated_apc, dao_contract.estimated_apc(deposit_epoch, 2190 * 5.5).round(2)
  end

  test "deposit_changes should return difference between beginning of today and current" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first
    expected_deposit_changes = dao_contract.total_deposit - latest_daily_statistic.total_dao_deposit.to_d

    assert_not_equal dao_contract.total_deposit, dao_contract.deposit_changes
    assert_equal expected_deposit_changes, dao_contract.deposit_changes
  end

  test "depositor_changes should return difference between beginning of today and current" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic, dao_depositors_count: 80)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first
    expected_depositor_changes = dao_contract.depositors_count - latest_daily_statistic.dao_depositors_count.to_d

    assert_not_equal dao_contract.depositors_count, dao_contract.depositor_changes
    assert_equal expected_depositor_changes, dao_contract.depositor_changes
  end

  test "unclaimed_compensation_changes should return between beginning of today and current" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100, unclaimed_compensation: 0)
    create_list(:daily_statistic, 2)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first
    expected_unclaimed_compensation_changes = dao_contract.unclaimed_compensation.to_d - latest_daily_statistic.unclaimed_compensation.to_d

    assert_equal expected_unclaimed_compensation_changes, dao_contract.unclaimed_compensation_changes
  end

  test "claimed_compensation_changes should return between beginning of today and current" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create_list(:daily_statistic, 2)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first
    expected_claimed_compensation_changes = dao_contract.claimed_compensation - latest_daily_statistic.claimed_compensation.to_d

    assert_equal expected_claimed_compensation_changes, dao_contract.claimed_compensation_changes
  end

  test "unclaimed_compensation should return beginning of today value" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first

    assert_equal latest_daily_statistic.unclaimed_compensation.to_d, dao_contract.unclaimed_compensation
  end

  test "average_deposit_time should return beginning of today value" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first

    assert_equal latest_daily_statistic.average_deposit_time, dao_contract.average_deposit_time
  end

  test "mining_reward should return beginning of today value" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first

    assert_equal latest_daily_statistic.mining_reward, dao_contract.mining_reward
  end

  test "deposit_compensation should return beginning of today value" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first

    assert_equal latest_daily_statistic.deposit_compensation, dao_contract.deposit_compensation
  end

  test "treasury_amount should return beginning of today value" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)
    create(:daily_statistic)
    latest_daily_statistic = DailyStatistic.order(id: :desc).first

    assert_equal latest_daily_statistic.treasury_amount, dao_contract.treasury_amount
  end

  test "deposit_changes should return current value when there is no daily_statistic" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)

    assert_equal dao_contract.total_deposit, dao_contract.deposit_changes
  end

  test "depositor_changes should return current value when there is no daily_statistic" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)

    assert_equal dao_contract.depositors_count, dao_contract.depositor_changes
  end

  test "unclaimed_compensation_changes should return zero when there is no daily_statistic" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)

    assert_equal 0, dao_contract.unclaimed_compensation_changes
  end

  test "claimed_compensation_changes should return zero when there is no daily_statistic" do
    dao_contract = create(:dao_contract, total_deposit: 10**21 * 100)

    assert_equal 0, dao_contract.claimed_compensation_changes
  end

  test "#ckb_transactions should return an empty array when there aren't transactions" do
    contract = DaoContract.default_contract

    assert_equal [], contract.ckb_transactions
  end

  test "#ckb_transactions should return correct transactions when there are dao transactions" do
    contract = DaoContract.default_contract
    address = create(:address)
    address1 = create(:address)

    30.times do |number|
      block = create(:block, :with_block_hash)
      cell_type = number % 2 == 0 ? "nervos_dao_deposit" : "nervos_dao_withdrawing"
      cell_output_address = number % 2 == 0 ? address : address1
      if number % 2 == 0
        tx = create(:ckb_transaction, block: block, tags: ["dao"])
        create(:cell_output, block: block, address: cell_output_address, ckb_transaction: tx, cell_type: cell_type)
      else
        tx = create(:ckb_transaction, block: block, tags: ["dao"])
        tx1 = create(:ckb_transaction, block: block, tags: ["dao"])
        create(:cell_output, block: block, address: cell_output_address, ckb_transaction: tx1, cell_type: cell_type)
        create(:cell_output, block: block, address: cell_output_address, ckb_transaction: tx, consumed_by: tx1,
                             status: "dead", cell_type: cell_type)
      end
    end

    ckb_transaction_ids = CellOutput.nervos_dao_deposit.pluck("ckb_transaction_id") + CellOutput.nervos_dao_withdrawing.pluck("ckb_transaction_id") + CellOutput.nervos_dao_withdrawing.pluck("consumed_by_id").compact
    expected_txs = CkbTransaction.where(id: ckb_transaction_ids.uniq).recent

    assert_equal expected_txs.pluck(:id), contract.ckb_transactions.recent.pluck(:id)
  end
end
