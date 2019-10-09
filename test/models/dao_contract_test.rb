require "test_helper"

class DaoContractTest < ActiveSupport::TestCase
  context "validations" do
    should validate_presence_of(:total_deposit)
    should validate_numericality_of(:total_deposit).
      is_greater_than_or_equal_to(0)
    should validate_presence_of(:subsidy_granted)
    should validate_numericality_of(:subsidy_granted).
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
    expected_attributes = %w(created_at deposit_transactions_count depositors_count id subsidy_granted total_deposit total_depositors_count updated_at withdraw_transactions_count)
    assert_equal expected_attributes, dao_contract.attributes.keys.sort
  end
end
