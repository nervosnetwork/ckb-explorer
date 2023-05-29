require "test_helper"

class ImportTransactionJobTest < ActiveJob::TestCase
  # test "the truth" do
  #   assert true
  # end

  # setup the previous cell outputs and contract that the raw tx requires
  setup do
  end

  test "import normal ckb transaction" do
    @cell_base_transaction = create :ckb_transaction, :with_single_output
    @cell_base = @cell_base_transaction.cell_outputs.first
    @raw_tx = {
      "cell_deps" =>
        [
          {
            "dep_type" => "code",
            "out_point" => {
              "index" => "0x3",
              "tx_hash" => "0x8f8c79eb6671709633fe6a46de93c0fedc9c1b8a6527a18d3983879542635c9f" } },
          {
            "dep_type" => "code",
            "out_point" => {
              "index" => "0x1",
              "tx_hash" => "0x8f8c79eb6671709633fe6a46de93c0fedc9c1b8a6527a18d3983879542635c9f" } }
        ],
      "hash" => "0xf8de3bb47d055cdf460d93a2a6e1b05f7432f9777c8c474abf4eec1d4aee5d37",
      "header_deps" => [],
      "inputs" => [
        {
          "previous_output" => {
            "index" => CkbUtils.int_to_hex(@cell_base.cell_index),
            "tx_hash" => @cell_base_transaction.tx_hash
          },
          "since" => "0x0"
        }
      ],
      "outputs" =>
  [
    {
      "capacity" => CkbUtils.int_to_hex(10**8 * 4),
      "lock" => {
        "args" => "0x57ccb07be6875f61d93636b0ee11b675494627d2",
        "code_hash" => "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8",
        "hash_type" => "type"
      },
      "type" => nil
    },
    {
      "capacity" => CkbUtils.int_to_hex(10**8 * 4 - 1),
      "lock" => {
        "args" => "0x64257f00b6b63e987609fa9be2d0c86d351020fb",
        "code_hash" => "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8",
        "hash_type" => "type"
      },
      "type" => nil
    }
  ],
      "outputs_data" => [],
      "version" => "0x0",
      "witnesses" => [
        "0x55f49d7979ba246aa2f05a6e9afd25a23dc39ed9085a0b1e33b6b3bb80d34dbd4031a04ea389d6d8ff5604828889aa06a827e930a7e89411b80f6c3e1404951f00"
      ]
    }
    ImportTransactionJob.new.perform @raw_tx
    assert_equal 2, CkbTransaction.count
    assert_equal 1, CellInput.count
    assert_equal 3, CellOutput.count
    assert_equal 4, Address.count
    assert_equal 4, AccountBook.count
  end

  test "import transaction which wants to consume non-exists cells" do
    # this will halt the import process, only leave a pending transaction
    raw_tx = {
      "cell_deps" =>
        [
          {
            "dep_type" => "code",
            "out_point" => {
              "index" => "0x3",
              "tx_hash" => "0x8f8c79eb6671709633fe6a46de93c0fedc9c1b8a6527a18d3983879542635c9f" } },
          {
            "dep_type" => "code",
            "out_point" => {
              "index" => "0x1",
              "tx_hash" => "0x8f8c79eb6671709633fe6a46de93c0fedc9c1b8a6527a18d3983879542635c9f" } }
        ],
      "hash" => "0xf8de3bb47d055cdf460d93a2a6e1b05f7432f9777c8c474abf4eec1d4aee5d37",
      "header_deps" => [],
      "inputs" => [
        {
          "previous_output" => {
            "index" => "0x0",
            "tx_hash" => "0x519c09b28e1170b8ee89523b75965dae2f7dd209e88c98008286e996bad46e07"
          },
          "since" => "0x0"
        }
      ],
      "outputs" =>
      [
        {
          "capacity" => CkbUtils.int_to_hex(10**8 * 4),
          "lock" => {
            "args" => "0x57ccb07be6875f61d93636b0ee11b675494627d2",
            "code_hash" => "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8",
            "hash_type" => "type"
          },
          "type" => nil
        },
        {
          "capacity" => CkbUtils.int_to_hex(10**8 * 4 - 1),
          "lock" => {
            "args" => "0x64257f00b6b63e987609fa9be2d0c86d351020fb",
            "code_hash" => "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8",
            "hash_type" => "type"
          },
          "type" => nil
        }
      ],
      "outputs_data" => [],
      "version" => "0x0",
      "witnesses" => [
        "0x55f49d7979ba246aa2f05a6e9afd25a23dc39ed9085a0b1e33b6b3bb80d34dbd4031a04ea389d6d8ff5604828889aa06a827e930a7e89411b80f6c3e1404951f00"
      ]
    }

    assert_difference -> { CkbTransaction.count } => 1,
                      -> { CellInput.count } => 1,
                      -> { CellOutput.count } => 2,
                      -> { AccountBook.count } => 2,
                      -> { Address.count } => 2 do
      ImportTransactionJob.new.perform raw_tx
    end
  end
end
