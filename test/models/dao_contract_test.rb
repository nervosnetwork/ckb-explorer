require "test_helper"

class DaoContractTest < ActiveSupport::TestCase
  context "validations" do
    should validate_presence_of(:total_deposit)
    should validate_numericality_of(:total_deposit).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:interest_granted)
    should validate_numericality_of(:interest_granted).
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
    expected_attributes = %w(created_at deposit_transactions_count depositors_count id interest_granted total_deposit total_depositors_count updated_at withdraw_transactions_count)
    assert_equal expected_attributes, dao_contract.attributes.keys.sort
  end

  test "estimated apc when deposit period is less than one year" do
    dao_contract = DaoContract.default_contract
    expected_estimated_apc = 3.7
    deposit_epoch = OpenStruct.new(number: 0, index:0, length: 1800)
    assert_equal expected_estimated_apc, dao_contract.estimated_apc(deposit_epoch, 2190 * 0.19).round(2)
  end

  test "estimated apc when deposit period is one year cross period" do
    dao_contract = DaoContract.default_contract
    expected_estimated_apc = 2.44
    deposit_epoch = OpenStruct.new(number: 2190 * 3.5, index:0, length: 1800)

    assert_equal expected_estimated_apc, dao_contract.estimated_apc(deposit_epoch).round(2)
  end

  test "estimated apc when deposit period is more than four year" do
    dao_contract = DaoContract.default_contract
    expected_estimated_apc = 2.94
    deposit_epoch = OpenStruct.new(number: 0, index:0, length: 1800)

    assert_equal expected_estimated_apc, dao_contract.estimated_apc(deposit_epoch, 2190 * 5.5).round(2)
  end
end
