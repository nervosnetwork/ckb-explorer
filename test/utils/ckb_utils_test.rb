require "test_helper"

class CkbUtilsTest < ActiveSupport::TestCase
  setup do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x3e8",
        number: "0x0",
        start_number: "0x0"
      )
    )
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    CkbSync::Api.any_instance.stubs(:get_block_cycles).returns(
      [
        "0x100", "0x200", "0x300", "0x400", "0x500", "0x600", "0x700", "0x800", "0x900"
      ]
    )
    GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
  end

  test ".generate_address should return mainnet address when mode is mainnet" do
    ENV["CKB_NET_MODE"] = "mainnet"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      Settings.code_hash,
      "data"
    )

    assert CkbUtils.generate_address(lock_script).start_with?("ckb")
    ENV["CKB_NET_MODE"] = "testnet"
  end

  test ".parse_address raise error when address is mainnet address and mode is testnet" do
    assert_raises CkbAddressParser::InvalidPrefixError do
      CkbUtils.parse_address("haha1qygndsefa43s6m882pcj53m4gdnj4k440axqsm2hnz")
    end
  end

  test ".parse_address should not raise error when address is mainnet address and mode is mainnet" do
    ENV["CKB_NET_MODE"] = "mainnet"
    assert_nothing_raised do
      CkbUtils.parse_address("ckb1qyqpr9t74uzvr6wrlenw44lfjzcne8ksl64s279w4l")
    end

    ENV["CKB_NET_MODE"] = "testnet"
  end

  test ".generate_address should return full payload address when use correct sig code match" do
    ENV["CKB_NET_MODE"] = "testnet"
    short_payload_blake160_address = "ckt1q2tnhkeh8ja36aftftqqdc4mt0wtvdp3a54kuw2tyfepezgx52khydkr98kkxrtvuag8z2j8w4pkw2k6k4l5cwfw473"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      Settings.code_hash,
      "data"
    )

    assert_equal short_payload_blake160_address,
                 CkbUtils.generate_address(lock_script,
                                           CKB::Address::Version::CKB2019)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".generate_address should return short payload blake160 address when use correct sig type match" do
    ENV["CKB_NET_MODE"] = "testnet"
    # short_payload_blake160_address = "ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83"
    short_payload_blake160_address = "ckt1qzda0cr08m85hc8jlnfp3zer7xulejywt49kt2rr0vthywaa50xwsqfkcv576ccddnn4quf2ga65xee2m26h7nq4sds0r"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      Settings.secp_cell_type_hash
    )

    assert_equal short_payload_blake160_address,
                 CkbUtils.generate_address(lock_script)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".generate_address should return full payload address when use correct multisig code match" do
    ENV["CKB_NET_MODE"] = "testnet"
    short_payload_blake160_address = "ckt1qtqlkzhxj9wn6nk76dyc4m04ltwa330khkyjrc8ch74at67t7fvmcdkr98kkxrtvuag8z2j8w4pkw2k6k4l5ce7s8yp"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      Settings.secp_multisig_cell_code_hash,
      "data"
    )

    assert_equal short_payload_blake160_address,
                 CkbUtils.generate_address(lock_script,
                                           CKB::Address::Version::CKB2019)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".generate_address should return short payload multisig address when use correct multisig type match" do
    ENV["CKB_NET_MODE"] = "testnet"
    # short_payload_blake160_address = "ckt1qyqndsefa43s6m882pcj53m4gdnj4k440axqyz2gg9"
    short_payload_blake160_address = "ckt1qpw9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sqfkcv576ccddnn4quf2ga65xee2m26h7nqwuqak4"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      Settings.secp_multisig_cell_type_hash
    )

    assert_equal short_payload_blake160_address,
                 CkbUtils.generate_address(lock_script)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".generate_address should return full payload data address when do not use default lock script and hash type is data" do
    ENV["CKB_NET_MODE"] = "testnet"
    full_payload_address = "ckt1qgvf96jqmq4483ncl7yrzfzshwchu9jd0glq4yy5r2jcsw04d7xlydkr98kkxrtvuag8z2j8w4pkw2k6k4l5csspk07"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      "0x1892ea40d82b53c678ff88312450bbb17e164d7a3e0a90941aa58839f56f8df2",
      "data"
    )

    assert_equal full_payload_address,
                 CkbUtils.generate_address(lock_script,
                                           CKB::Address::Version::CKB2019)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".generate_address should return full payload data address when do not use default lock script and hash type is type" do
    ENV["CKB_NET_MODE"] = "testnet"
    full_payload_address = "ckt1qjn9dutjk669cfznq7httfar0gtk7qp0du3wjfvzck9l0w3k9eqhvdkr98kkxrtvuag8z2j8w4pkw2k6k4l5ca2tat0"
    lock_script = CKB::Types::Script.generate_lock(
      "0x36c329ed630d6ce750712a477543672adab57f4c",
      "0xa656f172b6b45c245307aeb5a7a37a176f002f6f22e92582c58bf7ba362e4176"
    )

    assert_equal full_payload_address,
                 CkbUtils.generate_address(lock_script,
                                           CKB::Address::Version::CKB2019)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".generate_address should return nil when do not use default lock script and args is empty" do
    ENV["CKB_NET_MODE"] = "testnet"
    full_payload_address = "ckt1qjn9dutjk669cfznq7httfar0gtk7qp0du3wjfvzck9l0w3k9eqhv77zeg7"
    lock_script = CKB::Types::Script.generate_lock(
      "0x",
      "0xa656f172b6b45c245307aeb5a7a37a176f002f6f22e92582c58bf7ba362e4176"
    )

    assert_equal full_payload_address,
                 CkbUtils.generate_address(lock_script,
                                           CKB::Address::Version::CKB2019)
    ENV["CKB_NET_MODE"] = "mainnet"
  end

  test ".parse_address should return block160 when target is short payload blake160 address" do
    blake160 = "0x36c329ed630d6ce750712a477543672adab57f4c"
    short_payload_blake160_address = "ckt1qyqrdsefa43s6m882pcj53m4gdnj4k440axqswmu83"

    assert_equal blake160,
                 CkbUtils.parse_address(short_payload_blake160_address).script.args
  end

  test ".parse_address should return an hash that contains format type, code hash and args when target is full payload address" do
    full_payload_address = "ckt1q2n9dutjk669cfznq7httfar0gtk7qp0du3wjfvzck9l0w3k9eqhv9pkcv576ccddnn4quf2ga65xee2m26h7nq2rtnac"
    parsed_result = CkbUtils.parse_address(full_payload_address)

    assert_equal "0xa656f172b6b45c245307aeb5a7a37a176f002f6f22e92582c58bf7ba362e4176",
                 parsed_result.script.code_hash
    assert_equal "0x1436c329ed630d6ce750712a477543672adab57f4c",
                 parsed_result.script.args
    assert_equal "data", parsed_result.script.hash_type
    assert_equal "FULL", parsed_result.address_type
  end

  test ".base_reward should return 0 for genesis block" do
    VCR.use_cassette("genesis_block", record: :new_episodes) do
      node_block = CkbSync::Api.instance.get_block_by_number(0)

      local_block = CkbSync::NewNodeDataProcessor.new.process_block(node_block)

      assert_equal 0, local_block.reward
    end
  end

  test ".calculate_cell_min_capacity should return output's min capacity" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      node_data_processor.process_block(node_block)
      output = node_block.transactions.first.outputs.first
      output_data = node_block.transactions.first.outputs_data.first

      expected_cell_min_capacity = output.calculate_min_capacity(output_data)

      assert_equal expected_cell_min_capacity,
                   CkbUtils.calculate_cell_min_capacity(output, output_data)
    end
  end

  test ".block_cell_consumed generated block's cell_consumed should equal to the sum of transactions output occupied capacity" do
    CkbSync::Api.any_instance.stubs(:get_block_cycles).returns(
      [
        "0x100", "0x200", "0x300", "0x400", "0x500", "0x600", "0x700", "0x800", "0x900"
      ]
    )
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      node_data_processor.process_block(node_block)
      outputs_data = node_block.transactions.flat_map(&:outputs_data).flatten
      expected_total_cell_consumed =
        node_block.transactions.flat_map(&:outputs).flatten.each_with_index.reduce(0) do |memo, (output, index)|
          memo + output.calculate_min_capacity(outputs_data[index])
        end

      assert_equal expected_total_cell_consumed,
                   CkbUtils.block_cell_consumed(node_block.transactions)
    end
  end

  test ".address_cell_consumed should return right cell consumed by the address" do
    prepare_node_data(12)
    VCR.use_cassette("blocks/12") do
      node_block = CkbSync::Api.instance.get_block_by_number(13)
      cellbase = node_block.transactions.first
      lock_script = CkbUtils.generate_lock_script_from_cellbase(cellbase)
      miner_address = Address.find_or_create_address(lock_script,
                                                     node_block.header.timestamp)
      unspent_cells = miner_address.cell_outputs.live
      expected_address_cell_consumed =
        unspent_cells.reduce(0) do |memo, cell|
          memo + cell.node_output.calculate_min_capacity(cell.data)
        end

      assert_equal expected_address_cell_consumed,
                   CkbUtils.address_cell_consumed(miner_address.address_hash)
    end
  end

  test ".ckb_transaction_fee should return right tx_fee when tx is not dao withdraw tx" do
    node_block = fake_node_block("0x3307186493c5da8b91917924253a5ffd35231151649d0c7e2941aa8801815063")
    create(:block, :with_block_hash, number: node_block.header.number - 1)
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      block = create(:block, :with_block_hash)
      ckb_transaction1 = create(:ckb_transaction,
                                tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      ckb_transaction2 = create(:ckb_transaction,
                                tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction1, cell_index: 1,
                           tx_hash: "0x498315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      create(:cell_output, ckb_transaction: ckb_transaction2, cell_index: 2,
                           tx_hash: "0x598315db9c7ba144cca74d2e9122ac9b3a3da1641b2975ae321d91ec34f1c0e3", block: block)
      node_data_processor.process_block(node_block)
      node_tx = node_block.transactions.last
      ckb_transaction = CkbTransaction.find_by(tx_hash: node_tx.hash)
      input_capacities = { ckb_transaction.id => [800000000] }
      output_capacities = { ckb_transaction.id => [500000000] }

      assert_equal 10**8 * 3,
                   CkbUtils.ckb_transaction_fee(ckb_transaction,
                                                input_capacities[ckb_transaction.id].sum, output_capacities[ckb_transaction.id].sum)
    end
  end

  test ".parse_epoch_info should return epoch 0 info if epoch is equal to 0" do
    header = OpenStruct.new(epoch: 0, number: 0)

    assert_equal CkbUtils.get_epoch_info(0), CkbUtils.parse_epoch_info(header)
  end

  test ".parse_epoch_info should return correct epoch info" do
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}") do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      header = node_block.header
      epoch_info = CkbUtils.parse_epoch_info(header)
      expected_epoch_info = CkbUtils.get_epoch_info(epoch_info.number)

      assert_equal expected_epoch_info.number, epoch_info.number
      assert_equal expected_epoch_info.start_number, epoch_info.start_number
      assert_equal expected_epoch_info.length, epoch_info.length
    end
  end

  test ".parse_dao should return nil whne dao is blank" do
    assert_nil CkbUtils.parse_dao(nil)
  end

  test ".parse_dao should return one open sturct with right attributes" do
    dao = "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007"
    bin_dao = CKB::Utils.hex_to_bin(dao)
    c_i = bin_dao[0..7].unpack("Q<").pack("Q>").unpack1("H*").hex
    ar_i = bin_dao[8..15].unpack("Q<").pack("Q>").unpack1("H*").hex
    s_i = bin_dao[16..23].unpack("Q<").pack("Q>").unpack1("H*").hex
    u_i = bin_dao[24..-1].unpack("Q<").pack("Q>").unpack1("H*").hex
    parsed_dao = CkbUtils.parse_dao("0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")

    assert_equal c_i, parsed_dao.c_i
    assert_equal ar_i, parsed_dao.ar_i
    assert_equal s_i, parsed_dao.s_i
    assert_equal u_i, parsed_dao.u_i
  end

  test "should return 0 when sudt_amount raise Runtime error" do
    assert_equal 0, CkbUtils.parse_udt_cell_data("0x01")
  end

  test "cell_type should return testnet m_nft_issuer when type script code_hash match m_nft_issuer code_hash" do
    type_script = CKB::Types::Script.new(
      code_hash: Settings.testnet_issuer_script_code_hash, hash_type: "type", args: "0x"
    )
    assert_equal "m_nft_issuer", CkbUtils.cell_type(type_script, "0x")
  end

  test "cell_type should return mainnet m_nft_issuer when type script code_hash match m_nft_issuer code_hash" do
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb"))
    type_script = CKB::Types::Script.new(
      code_hash: Settings.mainnet_issuer_script_code_hash, hash_type: "type", args: "0x"
    )
    assert_equal "m_nft_issuer", CkbUtils.cell_type(type_script, "0x")
  end

  test "cell_type should return testnet m_nft_class when type script code_hash match m_nft_class code_hash" do
    type_script = CKB::Types::Script.new(
      code_hash: Settings.testnet_token_class_script_code_hash, hash_type: "type", args: "0x"
    )
    assert_equal "m_nft_class", CkbUtils.cell_type(type_script, "0x")
  end

  test "cell_type should return mainnet m_nft_class when type script code_hash match m_nft_class code_hash" do
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb"))
    type_script = CKB::Types::Script.new(
      code_hash: Settings.mainnet_token_class_script_code_hash, hash_type: "type", args: "0x"
    )
    assert_equal "m_nft_class", CkbUtils.cell_type(type_script, "0x")
  end

  test "cell_type should return testnet m_nft_token when type script code_hash match m_nft_token code_hash" do
    type_script = CKB::Types::Script.new(
      code_hash: Settings.testnet_token_script_code_hash, hash_type: "type", args: "0x"
    )
    assert_equal "m_nft_token", CkbUtils.cell_type(type_script, "0x")
  end

  test "cell_type should return mainnet m_nft_token when type script code_hash match m_nft_token code_hash" do
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb"))
    type_script = CKB::Types::Script.new(
      code_hash: Settings.mainnet_token_script_code_hash, hash_type: "type", args: "0x"
    )
    assert_equal "m_nft_token", CkbUtils.cell_type(type_script, "0x")
  end

  test "parse_issuer_data should return correct info" do
    version = 0
    class_count = 0
    set_count = 0
    info = { name: "alice" }.stringify_keys!
    parsed_data = CkbUtils.parse_issuer_data("0x00000000000000000000107b226e616d65223a22616c696365227d")

    assert_equal version, parsed_data.version
    assert_equal class_count, parsed_data.class_count
    assert_equal set_count, parsed_data.set_count
    assert_equal info, parsed_data.info
  end

  test "parse_token_class_data should return correct info" do
    version = 0
    total = 1000
    issued = 0
    configure = "11000000".to_i(2)
    name = "First NFT"
    description = "First NFT"
    renderer = "https://xxx.img.com/yyy"
    data = "0x00000003e800000000c000094669727374204e465400094669727374204e4654001768747470733a2f2f7878782e696d672e636f6d2f797979"
    parsed_data = CkbUtils.parse_token_class_data(data)

    assert_equal version, parsed_data.version
    assert_equal total, parsed_data.total
    assert_equal issued, parsed_data.issued
    assert_equal configure, parsed_data.configure
    assert_equal name, parsed_data.name
    assert_equal description, parsed_data.description
    assert_equal renderer, parsed_data.renderer
  end

  test "parse nrc 721 token cell args" do
    args = "0x00000000000000000000000000000000000000000000000000545950455f4944013620e2ced53373c5b55c5cef79b7fd0a875c60a70382a9e9664fe28e0bb345ab22c70f8e24a90dcccc7eb1ea669ac6cfecab095a1886af01d71612fdb3c836c8"
    parsed_args = CkbUtils.parse_nrc_721_args(args)
    assert_equal "0x00000000000000000000000000000000000000000000000000545950455f4944",
                 parsed_args.code_hash
    assert_equal "type", parsed_args.hash_type
    assert_equal "0x3620e2ced53373c5b55c5cef79b7fd0a875c60a70382a9e9664fe28e0bb345ab",
                 parsed_args.args
    assert_equal "22c70f8e24a90dcccc7eb1ea669ac6cfecab095a1886af01d71612fdb3c836c8",
                 parsed_args.token_id
  end

  test "parse nrc 721 factory cell data" do
    data = "0x24ff5a9ab8c38d195ce2b4ea75ca898700125465737420746f6b656e20666163746f727900035454460015687474703a2f2f746573742d746f6b656e2e636f6d"
    parsed_data = CkbUtils.parse_nrc_721_factory_data(data)
    name = "Test token factory"
    symbol = "TTF"
    base_token_uri = "http://test-token.com"
    extra_data = ""
    assert_equal name, parsed_data.name
    assert_equal symbol, parsed_data.symbol
    assert_equal base_token_uri, parsed_data.base_token_uri
    assert_equal extra_data, parsed_data.extra_data
  end

  private

  def node_data_processor
    CkbSync::NewNodeDataProcessor.new
  end
end
