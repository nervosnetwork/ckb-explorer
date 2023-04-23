require "test_helper"

class CellOutputTest < ActiveSupport::TestCase
  context "associations" do
    should belong_to(:ckb_transaction)
    should belong_to(:address)
    # should belong_to(:block)
    should have_many(:cell_dependencies)
    # should have_many(:referring_cells)
  end

  context "validations" do
    should validate_presence_of(:capacity)
    should validate_numericality_of(:capacity).
      is_greater_than_or_equal_to(0)
  end

  test "should have cell_type column" do
    block = create(:block)
    cell_output = create(:cell_output, :with_full_transaction, block: block)

    assert_equal "normal", cell_output.cell_type
  end

  test "#to_raw should contain correct keys" do
    block = create(:block)
    cell_output = create(:cell_output, :with_full_transaction, block: block)
    raw = cell_output.to_raw
    assert_equal %i(capacity lock type).sort, raw.keys.sort
    assert_equal raw[:lock][:code_hash], cell_output.lock_script.code_hash
    assert_equal raw[:lock][:args], cell_output.lock_script.args
    assert_equal raw[:lock][:hash_type], cell_output.lock_script.hash_type
    assert_equal raw[:type][:code_hash], cell_output.type_script.code_hash
    assert_equal raw[:type][:args], cell_output.type_script.args
    assert_equal raw[:type][:hash_type], cell_output.type_script.hash_type
  end
end
