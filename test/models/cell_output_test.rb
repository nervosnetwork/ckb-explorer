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

  test "set data should update data_size & data_hash" do
    cell = create(:cell_output, :with_full_transaction)
    cell.data = "0x1234"
    assert_equal cell.data_size, 2
    assert_equal CKB::Utils.bin_to_hex(CKB::Blake2b.digest("\x12\x34")), cell.data_hash
    assert_equal "\x12\x34", cell.cell_datum.data
    assert_equal "\x12\x34", cell.binary_data
    assert_equal "0x1234", cell.data
  end

  test "set cell datum via nested attributes" do
    tx = create :ckb_transaction
    address = create :address
    co = tx.cell_outputs.create cell_datum_attributes: { data: "1234" },
                                occupied_capacity: 0,
                                address_id: address.id,
                                block_id: tx.block_id,
                                tx_hash: tx.tx_hash,
                                block_timestamp: tx.block_timestamp,
                                lock_script_id: address.lock_script.id

    assert_equal co.cell_datum.data, "1234"
    # assert_equal 4, co.data_size
  end
end
