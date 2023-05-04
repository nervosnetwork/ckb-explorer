require "test_helper"

class ImportTransactionJobTest < ActiveJob::TestCase
  # test "the truth" do
  #   assert true
  # end

  # here is an example of a raw transaction hash
  RAW_TX = {}
  RAW_CELLBASE_TX = {}

  # setup the previous cell outputs and contract that the raw tx requires
  setup do
  end

  test "import cellbase transaction" do
  end

  test "import normal ckb transaction" do
    ImportTransactionJob.new.perform RAW_TX
    assert_equal 1, CkbTransaction.count
    assert_equal 1, CellInput.count
    assert_equal 1, CellOutput.count
    assert_equal 1, AccountBook.count
    assert_equal 1, Address.count
  end

  test "import transaction which wants to consume non-exists cells" do
    # this will halt the import process, only leave a pending transaction
  end
end
