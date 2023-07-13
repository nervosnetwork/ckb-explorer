require "test_helper"

class CellDatumTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
  setup do
    @cell = create :cell_output, :with_full_transaction
    @cell_datum = @cell.build_cell_datum
  end

  test "update cell data_size" do
    @cell_datum.update data: "1234"
    assert_equal @cell.reload.data_size, 4
  end

  test "update cell data_hash" do
    @cell_datum.update data: "1234"
    assert_equal @cell.reload.data_hash, CKB::Utils.bin_to_hex(CKB::Blake2b.digest("1234"))
  end
end
