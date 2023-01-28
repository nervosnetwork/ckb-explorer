require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    create :deployed_cell
  end

  test "create deployed_cell" do
    deployed_cell = create :deployed_cell
    assert_equal false, deployed_cell.is_initialized
    assert_equal 1, deployed_cell.cell_id
    assert_equal 1, deployed_cell.contract_id
  end

  test "update deployed_cell" do
    deployed_cell = create :deployed_cell
    deployed_cell.update is_initialized: true, cell_id: 2, contract_id: 2
    assert_equal true, deployed_cell.is_initialized
    assert_equal 2, deployed_cell.cell_id
    assert_equal 2, deployed_cell.contract_id
  end

end
