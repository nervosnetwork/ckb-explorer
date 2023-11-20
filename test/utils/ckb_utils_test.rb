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

  test ".epoch_reward_with_halving should changed after halving" do
    assert_equal 95890410958904,
                 CkbUtils.epoch_reward_with_halving(8760)
    assert_equal 95890410958904,
                 CkbUtils.epoch_reward_with_halving(8761)
    assert_equal 47945205479452,
                 CkbUtils.epoch_reward_with_halving(17520)
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

  test "hexes to bins" do
    hashes = [
      "0x7f7d0a35a8a985ac5a504d445122f3b45564b6b2e0cd5b8b809d5f3a2c927814",
      "0x706fef723f0762fc363a9438bac0b03e5258711a99243ed0bebd69b025a17eed"
    ]
    values = CkbUtils.hexes_to_bins(hashes)
    assert_equal values.length, 2
    assert_equal values.first.unpack("H*"), ["7f7d0a35a8a985ac5a504d445122f3b45564b6b2e0cd5b8b809d5f3a2c927814"]
  end

  test "parse spore cluster data" do
    data = "0x270000000c0000001b0000000b000000434b424578706c6f72657208000000466f722054657374"
    info = CkbUtils.parse_spore_cluster_data(data)
    assert_equal info[:name], "CKBExplorer"
    assert_equal info[:description], "For Test"
  end

  test "parse spore cluster data with error data" do
    data = "0x270000"
    info = CkbUtils.parse_spore_cluster_data(data)
    assert_nil info[:name]
    assert_nil info[:description]
  end

  test "parse spore cell inner cluster data" do
    data = "0x26260000100000001e000000022600000a000000696d6167652f6a706567e0250000ffd8ffe000104a46494600010101012c012c0000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc000110801df01db03012200021101031101ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f0100030101010101010101010000000000000102030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a535455565758595a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffda000c03010002110311003f00f5fa28a2bbce40a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a2b2753f1168fa6645eea36f1b8ea81b737fdf2326b97d43e28691012b676f7574c3a1c0453f89e7f4a2c349b3bea2bc7af7e29ea526459d8dac00f772d211fc87e958577e3bf115ce73a8b46be9122ae3f1033fad3e563e467bf532491231991d507ab1c57cdd73ad6a9739fb46a579267b34ec47f3aa0ccce72c4b1f52734f947eccfa5a4d574e8ffd65fda27fbd328feb509f1068cbd756d3c7d6e53fc6be6ea28e51fb33e901e21d14f4d5f4e3ff006f29fe352a6b3a649f7352b26fa4ea7fad7cd5451ca1eccfa7e2b8866ff55346ff00eeb0352d7cb756edf52bfb6c7d9ef6ea2c7fcf39597f91a3945eccfa668af9eed7c67e21b5c797aa4ed8ff009eb893ff004206b6ecbe27eb30e05cc36970bdc942adf9838fd28e562e467b4d15e6f61f156ca4c0bfd3e784fac4c241fae2ba7d37c65a0ea1810ea30a39fe09b319fa7cd807f0a56627168e868a6a32ba86460ca79041c834ea420a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a29090a0924003924d71de21f885a4697ba2b5637f7238db09f901f77e9f966804ae765589ad78a347d1b72dedec6251ff2c63f9dff0021d3f1c578f6bde39d6b57dc9f68fb2db9ff009656f95c8f73d4fe78ae5cf2726a944b50ee7a76b1f15246dc9a3d8aa0ed25c1c9ff00be474fccd715aaf89f59d5770bcd427643d6343b13f218158d45558b514828a28a0a0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2802f69babea1a636ed3ef27b7ef847201fa8e86bb2d23e27ea76fb5752b786f13bb2feedff004e3f4af3fa28b09a4cf7ad17c79a1ea9b50dcfd9263fc173f27e4dd3f5aea548650ca410790477af972b6344f126ada2b0fb05e48b18eb137cc87fe027fa54b890e1d8fa328af3af0ffc4eb3b9db16b501b590f1e6c7968cfd4751fad77f697505e40b3da4d1cd0b7478d8303f88a9b58cda6b726a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28acfd6b58b1d16d0dc6a33ac49fc23ab39f403b9a00d0ae4fc51e39d2f43df0a37daef471e4c47853fed3741f4e4fb579ef8b3e205feafbedf4fdd656478f94fef1c7b9edf41f99ae26a947b96a1dce83c47e2dd575e665ba9fcbb63d2de2f953f1f5fc6b9fa28aa34b5828a28a06145145001451450014514500145145001451450014514500145145001451450014514500145145001451450015a1a36b3a868d71e769d73242dfc4a0e55bea3a1acfa2811ec3e18f8956978520d6916d273c099798dbebdd7f51ef5e831c892c6af13aba30cab29c823d8d7cbb5bfe19f15ea7e1f900b597ccb6272d6f21ca1fa7a1f71fad4b890e1d8fa168ae77c2de2dd3bc4318581fc9bb032d6f21f9bea3fbc3e9fa57455266d5828a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a6bb2a233bb055519249c002bca7c73f109a632586812158feec974382dec9e83dff2f5a12b8d2b9d278cfc7569a1efb5b2db75a88e0ae7e488ff00b47d7d87e95e37ab6a779ab5e35d6a13bcd33773d00f403b0aa6492492724d15a25635514828a28a0a0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2801d148f0cab242ec9221cab29c107d41af51f067c46cecb3f10b60fdd4bb03ff431fd7f3f5af2ca286ae4b499f5123ac88af1b0646190ca7208f514eaf08f05f8d2efc3f22c13eeb8d389e622794f74ff000e9f4eb5ed9a5ea36baa5947776132cd03f461d8fa11d8fb543563271b16e8a28a420a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a8aeae21b4b7927b991628631b9dd8e0014977730d9db49717522c5046bb9dd8f005786f8ebc5f3f88ae4c30168b4d8dbe48fa173fde6ff000ed4d2b8e31b963c77e369b5c91ecec0b43a629fa34deedededf9fb717451566c95828a28a06145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450015b5e16f11def876f84d68dba16ff5b031f9641fd0fa1ac5a2811f48787b5bb3d7b4f5bab17c8e8f19fbd1b7a115a95f37787b5bbcd07514bbb17c1e8e87eec8be86bdefc35aeda78834e5bab36c11c49113f346de87fc7bd435632946c6b514514890a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a64d2a4313cb33aa4680b3331c00075269f5e39f137c5e75199f4ad364ff00428db1348a7fd6b0ec3fd91fa9fc29a571a5733bc7fe2f93c41746dad19934c89be51d0ca7fbc7fa0ae3e8a2acd92b05145140c28a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a002b53c37ae5de81a925dd9b67b49193f2c8be87fc7b565d1408fa4f41d5ed75cd362bdb27ca370ca7aa37753ef5a35f3d7837c493f87353132ee7b4930b3c59fbc3d47b8ed5efd637705f59c57569209209543230ee2a1ab18ca3627a28a290828a28a0028a28a0028a28a0028a28a0028a2b0fc61afc5e1ed1a4ba7c34edf24119fe27ff01d4d01b9ccfc51f15ff67dbb693a7c98bb997f7cea798d0f6fa9fe5f515e3b52dddccd79752dc5cc8649a562eec7a926a2ad12b1b25641451450505145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514574da0783eefc4969249a0dcdb5d5dc4bba4b276f2a603d541f9587b839f619a52928abc82d7399a2ac5fd95d69d7725adfdbcb6d7119c3472a9561f81aaf4d3b8051451400514514005773f0cfc56747bd1a7df49ff12fb86e198f1139eff43dff003f5ae1a8a04d5cfa928af3ff00859e27fed1b2fecabd933776ebfba663cc918fea3f97e35e8159b56306ac14514500145145001451450014514500364758a3692460a8a0b33138000ea6be7ef1c7885fc43ad3cca48b48b29029feeff7bea7afe43b577bf173c43f65b25d1ed5f135c0dd3907eec7d87e27f41ef5e4355146905d428a28aa340a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800ab7a4ea377a4ea305f69f334175036e475ec7fa8ec477aa9450d5f4607d3d0da68df16bc1305d5d42b0de806332c63e7b6947500f753c1c1ea08ef5f3af89b43bcf0e6b571a66a29b6784f0c3eeba9e8cbea0d7a4fece5abbdbf88afb4a763e4ddc1e6a8f4743fd549fc8575bfb4378792f7c390eb5120fb4d8384918753131c73f4623f335e6d39bc3d7f64fe17b1a35cd1b9f3ad14515e91985145140051451401674dbd9f4ebe82f2d1f64f0b0653fd0fb57d11e1cd5e0d734882fadf8120c3a679461d56be6eaed7e177887fb2759fb15c3e2cef085393c249fc27f1e87f0f4a4d5c89aba3dbe8a28a8320a28a2800a28a2800aabaa5f43a6e9d717972db61850bb7bfb0f73d2ad5796fc64d6ff00d468d037a4d3e3ff001d5febf9534ae34aecf39d63509b55d4ee2fae4e6599cb11e83b01ec060553a28ab360a28a281851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451401de7c0eddff000b374adbd36cdbbe9e53ff005c57d0df116149fc07e20493a0b199ff001552c3f502bc6bf672d21ee3c457daaba9f26d20f294fabb9fe8a0fe62bd4fe316a69a67c3cd5999807b8416c83fbc5ce0ff00e3bb8fe15e4629f362629791ac3489f27d14515eb990514514005145140051451401efbf0f75efeddf0fc6d3366f2dff0075367a923a37e23f5cd74f5e09f0e75bfec5f11c5e6b62d6e710cb9e8327e56fc0fe84d7bdd43563192b30a28a291214514500417b7315959cf7570db62850c8e7d80cd7cddac6a12ea9aa5cdf4e7f793b9723d0761f80c0fc2bd63e30eadf64d121d3a26c4976d97c7f7179fd4e3f235e3757146905d428a28a66814514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514aaa5982a8249e8077a004ab7a4e9d77ab6a3058e9f0b4f753b6d445ee7fa0ee4f6aea7c2df0d7c45e202922da8b2b33d6e2e8ec007b2fde3f963debd8fc3b69e0af86762ed3eab6b26a2cb8966660f337b2a2e4aafb7e64d7356c5461a435914a37dceafc05e1987c27e1ab7d36221e51fbc9e51ff002d243d4fd3a01ec057857c70f19c7e21d6a3d374e943e9b604e5d4e56597a161ea07407ebeb567e22fc5cbad760974ed0124b2d3dc159266389651e9c7dd1fa9fd2bca6b0c2e1a4a5ed6aee54a4ad641451457a06614514500145145001451450015f407c3fd67fb6bc356f2c8dbae61fdccd9ea5877fc460d7cff005ddfc22d5bec5afbd8c8d886f57033d9d791fa647e549ad089aba3da68a28a8320a28acdf126a234ad06faf720343112b9fef1e17f522803c4fe236a9fda9e2bbb656cc36e7ecf1fd17aff00e3d9ae66862598962493c927bd15a1ba560a28a28185145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140054d6773259ddc17301db2c2e2453e841c8a868a047d37a6ddc7a869f6d770ff00ab9e35917db2338ab35c27c20d4bed7e1b7b473992ce42a07fb0dc8fd777e55ddd66cc1ab30af3cf8cda8791a25a58a9c35ccbb987aaa0ff00123f2af43af11f8bb7df69f157d9c1f96d6154c7fb47e63fa11f9538ee5415d9c4d1451566c145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500771f08750fb2f89dad58e12ee22b8ff00697e61fa06fcebdb2be69d0af4e9dacd8de03810ccae7e80f23f2cd7d2a082323906a646535a8b5f36f896f3edfe20d46eb39124ee57fddcf1fa62be85d6ae7ec5a3df5d6706181e41f50a4d7cd144474c28a28aa340a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800afa37c2379f6ff000ce99704e59a050c7fda0307f506be72aecbc3fe32974ad22dec959808b774f7627fad26ae4495cf4cf89171f67f05ea4c0f2eab18ff00813007f4cd780d7b5fc619bcbf0a2203feb6e517f463fd2bc5288ec10d828a28a65851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451401ebbf1ae4c693a747fde9d9bf25ff00ebd79157aafc6e6c43a3afab4a7f209fe35e554a3b110d828a28a65851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451401ea5f1bf38d17d3f7dffb4ebcb6bd57e372e61d1dbd1a51f984ff000af2aa4b6221b0514514cb0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2803d77e35c79d274e93fbb3b2fe6bffd6af22af6bf8c30f99e144703fd55ca37e8c3fad78a528ec44360a28a2996145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145007bf7c48b7fb4782f525039455907fc05813fa66bc06be97d6adbedba3df5ae326681e31f52a457cd14a2670d828a28a66814514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014515d9787fc192eaba45bdeaab112eee9ecc47f4a04dd8f72af9b7c4b67f60f106a36b8c08e770bfeee78fd315f495788fc5db1fb378abed007cb750abe7fda1f29fd00fcea626707a9c4d1451546a14514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450015f46f846cfec3e19d32dc8c32c0a587fb4464fea4d78068564751d66c6cc0c89a6543ec09e4fe59afa540006070054c8cea316bcf3e3369fe7e89697ca32d6d2ed63e8ae3fc40fcebd0eb37c49a70d5741beb2c02d34442e7fbc395fd40a94427667cdb450c0ab10c0823820f6a2b4370a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2803b8f843a7fdabc4ed74c32969116cffb4df28fd0b7e55ed95c27c20d37ec9e1b7bc75c497921607fd85e07ebbbf3aeeea1ee632776145145224f01f88da5ff0065f8aeed55710dc1fb447f46ebff008f66b99afa96386195f13451c9e9bd41a7b69960df7acad4fd625ff0af37159a7d56a7b3942ff33d1c3e17db439948f95e8afa91b45d2dbef69b647eb027f8544de1dd11bef68fa69fadaa7f8573acfa1d60fef37fecf97f31f30515f4cbf853406eba369ff840a3f90a85fc17e1c7eba3da7e0b8fe554b3da5d62ff00027ea13ee8f9b28afa31fc03e187eba4c63e9238fe4d55e4f871e176e9a7327fbb7127f56ab59e50eb17f87f98bea153ba3e7ba2bdf24f85fe1b6fbb15d27fbb31feb5564f84fa0b7ddb8d453e92a1fe6b56b3ac33eff713f51abe4786d15ed12fc22d30ff00aad46f57fde0adfd055497e0f447fd56b2ebfef5b03ffb30ad166f857f6bf064bc1d5ec791515ea52fc20ba1feab5781bfde84aff5354e5f849ad2ff00aabdd3dfeacebffb2d68b33c2bda7f992f0b557d93ce68aee26f85fe238feec76b2ffb930feb8aa337c3df13c5d74b661ea92c6dfc9ab558dc3cb69afbd10e8545f659cad15b93784bc410fdfd1af8ff00b9096fe59acf9f4ad42df3e7d85dc58fefc2cbfcc56d1ab097c324fe64b8496e8a74504104820823b1a2ac90a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28ab569a6df5e63ec765733e7fe7944cdfc850ddb702ad15d1da781bc4f758f2b43be19ff009e91f97ffa162b62d7e1478b26c799650c19ff009e9709ff00b29359bad4d6f243e57d8e128af50b6f82daebe0dc5f69b10f456763ff00a08ad4b7f82129c1b8d7517d92d49fd4b0acde2e8afb43e49763c6e8af7683e09e98b8fb46ad78ff00ee22aff3cd6843f06fc371fdf9b5297fde9947f25159bc7d15d47ece47cf3457d290fc28f09c7f7eca697fdfb87fe8455e87e1c784a2fbba3447fdf9246fe6d50f31a7d98fd933e5da2bead8fc0fe188feee87607fde8837f3ab31f857c3f1fdcd0b4b07d7ec91e7f954bcc61d22c3d933e49a2bebf4d0f494fb9a5d82fd2dd07f4a9934cb04fb9656abf48947f4a5fda4bf947ecbccf8ea8afb296da04fbb044bf44029e2341d1147e14bfb4bfbbf8ffc00f65e67c65457d9e00030060514bfb4bfbbf8ff00c00f65e67c61457d9a634230517f2a6b5bc0df7a18cfd5453fed2feefe3ff003d9799f1a515f62b69d62ff007eced9beb129fe950be89a53fdfd32c5beb6e87fa53fed25fca1ecbccf902a6b3b692f2ee0b6806e966711a8f524e057d632785f4093fd6687a5b7d6d23ff0acebef0de8360f14d67a458c1741b28f1c214afb8c5694f1d1a9251512650e5572a69b691e9fa7db5a43feae08d635f7c0c66acd145751c81451450000e0823a8abcadb9411dea8d58b57eaa7ea2bc8cdf0fed297b45bc7f23d0cbeb724f91eccb1451457cb9ed85145140051451400514514005145140051451400514514005145140114d6f0ce313451c83d1d41fe759f3f87345b8cf9da45839f536e99fcf15ab45546728fc2ec2714f7473171e02f0ccf9dfa4c4bff5cddd3f91159773f0b7c3b2e7cb5bc83feb9cd9ff00d081aeee8ade38cc44769bfbccdd0a6f78a3cc2e7e10d8367ecdaa5d47ff005d2357fe58acbb9f84178b9fb36ab6f27a799114fe44d7b22a337dd527e82a74b499ba80bf535d54f32c67495fe48c6787a0b7563e7ebaf85be22873e58b3b8ffae7363ff4202b22ebc0fe25b6cf99a45c363fe79ed93ff4126be9e4b0fefbfe42a64b4857f84b7d4d7753cc717f69239a7468746cf912eb49d46d3fe3eac2ee1ffae90b2ff3156f4ef0c6bba8e0d96917d2a9e8e2160bff007d118afad95117eeaa8fa0a75762cca76d62ae73ba4afa33e6db0f84de29ba00cb6f6d680ffcf79c7fecbbaba3b0f82372d837facc31faac1097fd491fcabdbe8aca58facf6d015389e6563f06bc3f0e0dd5cdfdcb771bd517f2033fad6fd97c38f0a5a63668f1487d6676933f83122baea2b09622acb7932b952e86759e87a55963ec7a658c18ff009e502aff00215a34515936dee505145148028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a002b9cd467f3ee9883f2afcab5b1a9cfe45b1c1f9dfe515cf57a581a5bd4672e227f6428a28af48e60a28a2800a55255811d4525149a5256609b4ee8bcac19411d0d3aaadb3e0ed3d0f4ab55f178cc33c35570e9d3d0fa4c3d655a9a9750a28a2b94dc28a28a0028a28a0028a28a0028a28a0028a28009380093ed400515623b395fa80a3deacc7651afdf258fe42b6861e72e8632af08f5338024e00c9a992d657fe1c0f7e2b51115061140fa0a7574c706bed3309629fd94514b01fc6e4fb0ab096d1274404fbf353515d11a308ec8c255672dd88060714b4515a1985145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514550d5ae7c983629f9df8fa0aba707524a289949455d999a95c7da2e4953f22f0bfe35568a2bdf845422a2ba1e7c9b93bb0a28a2a841451450014514500157217de99ee3ad53a744e51b3dbbd7066184facd3d3e25b7f91d584c47b19ebb32f5148082011d296be41ab68cfa14ee145145200a28a2800a28ab10da48fcb7c83deaa3094dda289949455db2bd4b15bc927dd5e3d4f4ad08ad638f9c6e3ea6a7aeb8613acd9cb3c57f2a29c562a39918b7b0e2ad222a0c2281f4a7515d70a7187c28e695494f761451455901451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500325758a367738551935cddcccd3ccd2377e83d055cd5aefcd7f2a33f229e4fa9aceaf5f0743923cef7671d7a9ccec828a28aed300a28a2800a28a2800a28a2800a28a28026b79369da7a1e956ab3eacc12ee1b5baf6f7af9fcd703bd7a6bd7fcff00ccf57018aff9753f97f913d145490c2f29c20e3b9ec2bc149c9d91eab692bb23ab10da3c9c9f957d4d5c82d522c13f337a9ab15db4f09d667254c4f4810c36f1c5f7464fa9eb53514576462a2ac8e47272776145145310514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400567ea977e4a79719fde30fc854f7d74b6d16e3cb9fba3d6b9e91da472ee72c4e49aeec261f9df3cb630ad539572adc6d14515eb1c61451450014514500145145001451450014514500140e0d1450069e9a12e18891b0c3f87d6b6154280140007615caa33238642430e4115bfa7deadcaed6c094751ebee2bc6af818d16e74d69fd7e07743132a9eecd9728a28ae4350a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a86eae12de22eff80f5345cce96f19790fd07735cf5d5c3dcca5dcfd07a57561b0eeabbbd8caad550565b897133cf29790f27b7a5474515eca492b2385bbeac28a28a6014514500145145001451450014514500145145001451450014a8cc8c19490c39045251401bda7dfadc00926165ffd0aaf5726090723835af61a90388ee0e0f67f5fad79789c25bdea7b763aa956be923568a28af3ce90a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a82eee52da3dce724f45ee6a2bebe4b605570d2fa7a7d6b0a591e590bc8c4b1aedc3e15d4f7a5b1855aca3a2dc75ccef7121790fd07615151457ac928ab238dbbeac28a28a601451450014514500145145001451450014514500145145001451450014514500145145005db1d41edf08f978bd3b8fa56dc32a4c81e360cb5cbd4904d240fba2620ff3ae3af848d4f7a3a336a759c747b1d451542cf518e6c2c988dfdfa1abf5e54e9ca9bb491d719292ba0a28a2a0a0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28aad757915b0f9ce5fb28eb5518b93b4509b495d96090a0924003a935937da9f54b63f57ff000aa777792dc9f98ed4eca3a556af4e860947dea9ab396a576f4881249249c9345145779ce145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500156ed2fe5830a4ef4fee9edf4aa9454ce119ab490e32717747476d790dc708d86fee9eb566b93abb6da94d0e039f317d1bafe75e755c0bde9b3a6188fe637e8aa96f7f04d81bb637a37156eb8650941da4ac7429296a828a28a8185145140051451400514514005145140051451400514514005145140051451400514514005145413dd4300fde3807d0726aa317276484da5b93d453cf1c0bba570a3f5359573aabb6440bb07a9e4d673bb3b16762cc7b935db4b03296b3d0c27884be1346ef5477cac0362ff0078f5ff00eb5669249249249ee68a2bd1a74a34d5a28e694dcb56145145684851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140054f05dcd07fab738f43c8a828a99454959a04dad51af0eac0f13478f75ff000abd0ddc137dc9173e87835cd515cb3c15397c3a1b46bc96fa9d6515cc4573345feae4603d339156e3d5665fbea8ff00a1ae59606a2f85dcd96222f73728acd8f5688fdf8dd7e9cd588afade4385739f420d73ca8548ef1345522f665aa2901c8c8a5ac8b0a28a2900514514005145140051504b750c3feb1f1f81aacfaac0bf755dbf0c56b1a3527b225ce2b76685158d26af21ff00571aafd4e6aa4b7b7127de9580f45e2ba2381a8f7d0c9d78ad8e8259a3887ef1d57ea6a8cdaac4bc44ace7d7a0ac52727268ae986060be2773296224f62dcfa85c4bc6ed8be8bc554a28aec8c230568ab18b9396e14514550828a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a00ffd9200000006ec74916945b561acc3c23eaf99a1ddd12eee990195a2a0b8709543f576153bd"""
    info = CkbUtils.parse_spore_cell_data(data)
    assert_equal info[:content_type], "image/jpeg"
    assert_equal info[:cluster_id], "0x6ec74916945b561acc3c23eaf99a1ddd12eee990195a2a0b8709543f576153bd"
  end

  test "parse spore outside cluster cell data" do
    data =
      "0x02260000100000001e000000022600000a000000696d6167652f6a706567e0250000ffd8ffe000104a46494600010101012c012c0000ffdb00430006040506050406060506070706080a100a0a09090a140e0f0c1017141818171416161a1d251f1a1b231c1616202c20232627292a29191f2d302d283025282928ffdb0043010707070a080a130a0a13281a161a2828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828282828ffc000110801df01db03012200021101031101ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f0100030101010101010101010000000000000102030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a535455565758595a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffda000c03010002110311003f00f5fa28a2bbce40a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a2b2753f1168fa6645eea36f1b8ea81b737fdf2326b97d43e28691012b676f7574c3a1c0453f89e7f4a2c349b3bea2bc7af7e29ea526459d8dac00f772d211fc87e958577e3bf115ce73a8b46be9122ae3f1033fad3e563e467bf532491231991d507ab1c57cdd73ad6a9739fb46a579267b34ec47f3aa0ccce72c4b1f52734f947eccfa5a4d574e8ffd65fda27fbd328feb509f1068cbd756d3c7d6e53fc6be6ea28e51fb33e901e21d14f4d5f4e3ff006f29fe352a6b3a649f7352b26fa4ea7fad7cd5451ca1eccfa7e2b8866ff55346ff00eeb0352d7cb756edf52bfb6c7d9ef6ea2c7fcf39597f91a3945eccfa668af9eed7c67e21b5c797aa4ed8ff009eb893ff004206b6ecbe27eb30e05cc36970bdc942adf9838fd28e562e467b4d15e6f61f156ca4c0bfd3e784fac4c241fae2ba7d37c65a0ea1810ea30a39fe09b319fa7cd807f0a56627168e868a6a32ba86460ca79041c834ea420a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a29090a0924003924d71de21f885a4697ba2b5637f7238db09f901f77e9f966804ae765589ad78a347d1b72dedec6251ff2c63f9dff0021d3f1c578f6bde39d6b57dc9f68fb2db9ff009656f95c8f73d4fe78ae5cf2726a944b50ee7a76b1f15246dc9a3d8aa0ed25c1c9ff00be474fccd715aaf89f59d5770bcd427643d6343b13f218158d45558b514828a28a0a0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2802f69babea1a636ed3ef27b7ef847201fa8e86bb2d23e27ea76fb5752b786f13bb2feedff004e3f4af3fa28b09a4cf7ad17c79a1ea9b50dcfd9263fc173f27e4dd3f5aea548650ca410790477af972b6344f126ada2b0fb05e48b18eb137cc87fe027fa54b890e1d8fa328af3af0ffc4eb3b9db16b501b590f1e6c7968cfd4751fad77f697505e40b3da4d1cd0b7478d8303f88a9b58cda6b726a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28acfd6b58b1d16d0dc6a33ac49fc23ab39f403b9a00d0ae4fc51e39d2f43df0a37daef471e4c47853fed3741f4e4fb579ef8b3e205feafbedf4fdd656478f94fef1c7b9edf41f99ae26a947b96a1dce83c47e2dd575e665ba9fcbb63d2de2f953f1f5fc6b9fa28aa34b5828a28a06145145001451450014514500145145001451450014514500145145001451450014514500145145001451450015a1a36b3a868d71e769d73242dfc4a0e55bea3a1acfa2811ec3e18f8956978520d6916d273c099798dbebdd7f51ef5e831c892c6af13aba30cab29c823d8d7cbb5bfe19f15ea7e1f900b597ccb6272d6f21ca1fa7a1f71fad4b890e1d8fa168ae77c2de2dd3bc4318581fc9bb032d6f21f9bea3fbc3e9fa57455266d5828a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a6bb2a233bb055519249c002bca7c73f109a632586812158feec974382dec9e83dff2f5a12b8d2b9d278cfc7569a1efb5b2db75a88e0ae7e488ff00b47d7d87e95e37ab6a779ab5e35d6a13bcd33773d00f403b0aa6492492724d15a25635514828a28a0a0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2801d148f0cab242ec9221cab29c107d41af51f067c46cecb3f10b60fdd4bb03ff431fd7f3f5af2ca286ae4b499f5123ac88af1b0646190ca7208f514eaf08f05f8d2efc3f22c13eeb8d389e622794f74ff000e9f4eb5ed9a5ea36baa5947776132cd03f461d8fa11d8fb543563271b16e8a28a420a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a8aeae21b4b7927b991628631b9dd8e0014977730d9db49717522c5046bb9dd8f005786f8ebc5f3f88ae4c30168b4d8dbe48fa173fde6ff000ed4d2b8e31b963c77e369b5c91ecec0b43a629fa34deedededf9fb717451566c95828a28a06145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450015b5e16f11def876f84d68dba16ff5b031f9641fd0fa1ac5a2811f48787b5bb3d7b4f5bab17c8e8f19fbd1b7a115a95f37787b5bbcd07514bbb17c1e8e87eec8be86bdefc35aeda78834e5bab36c11c49113f346de87fc7bd435632946c6b514514890a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a64d2a4313cb33aa4680b3331c00075269f5e39f137c5e75199f4ad364ff00428db1348a7fd6b0ec3fd91fa9fc29a571a5733bc7fe2f93c41746dad19934c89be51d0ca7fbc7fa0ae3e8a2acd92b05145140c28a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a002b53c37ae5de81a925dd9b67b49193f2c8be87fc7b565d1408fa4f41d5ed75cd362bdb27ca370ca7aa37753ef5a35f3d7837c493f87353132ee7b4930b3c59fbc3d47b8ed5efd637705f59c57569209209543230ee2a1ab18ca3627a28a290828a28a0028a28a0028a28a0028a28a0028a2b0fc61afc5e1ed1a4ba7c34edf24119fe27ff01d4d01b9ccfc51f15ff67dbb693a7c98bb997f7cea798d0f6fa9fe5f515e3b52dddccd79752dc5cc8649a562eec7a926a2ad12b1b25641451450505145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514574da0783eefc4969249a0dcdb5d5dc4bba4b276f2a603d541f9587b839f619a52928abc82d7399a2ac5fd95d69d7725adfdbcb6d7119c3472a9561f81aaf4d3b8051451400514514005773f0cfc56747bd1a7df49ff12fb86e198f1139eff43dff003f5ae1a8a04d5cfa928af3ff00859e27fed1b2fecabd933776ebfba663cc918fea3f97e35e8159b56306ac14514500145145001451450014514500364758a3692460a8a0b33138000ea6be7ef1c7885fc43ad3cca48b48b29029feeff7bea7afe43b577bf173c43f65b25d1ed5f135c0dd3907eec7d87e27f41ef5e4355146905d428a28aa340a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800ab7a4ea377a4ea305f69f334175036e475ec7fa8ec477aa9450d5f4607d3d0da68df16bc1305d5d42b0de806332c63e7b6947500f753c1c1ea08ef5f3af89b43bcf0e6b571a66a29b6784f0c3eeba9e8cbea0d7a4fece5abbdbf88afb4a763e4ddc1e6a8f4743fd549fc8575bfb4378792f7c390eb5120fb4d8384918753131c73f4623f335e6d39bc3d7f64fe17b1a35cd1b9f3ad14515e91985145140051451401674dbd9f4ebe82f2d1f64f0b0653fd0fb57d11e1cd5e0d734882fadf8120c3a679461d56be6eaed7e177887fb2759fb15c3e2cef085393c249fc27f1e87f0f4a4d5c89aba3dbe8a28a8320a28a2800a28a2800aabaa5f43a6e9d717972db61850bb7bfb0f73d2ad5796fc64d6ff00d468d037a4d3e3ff001d5febf9534ae34aecf39d63509b55d4ee2fae4e6599cb11e83b01ec060553a28ab360a28a281851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451401de7c0eddff000b374adbd36cdbbe9e53ff005c57d0df116149fc07e20493a0b199ff001552c3f502bc6bf672d21ee3c457daaba9f26d20f294fabb9fe8a0fe62bd4fe316a69a67c3cd5999807b8416c83fbc5ce0ff00e3bb8fe15e4629f362629791ac3489f27d14515eb990514514005145140051451401efbf0f75efeddf0fc6d3366f2dff0075367a923a37e23f5cd74f5e09f0e75bfec5f11c5e6b62d6e710cb9e8327e56fc0fe84d7bdd43563192b30a28a291214514500417b7315959cf7570db62850c8e7d80cd7cddac6a12ea9aa5cdf4e7f793b9723d0761f80c0fc2bd63e30eadf64d121d3a26c4976d97c7f7179fd4e3f235e3757146905d428a28a66814514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514aaa5982a8249e8077a004ab7a4e9d77ab6a3058e9f0b4f753b6d445ee7fa0ee4f6aea7c2df0d7c45e202922da8b2b33d6e2e8ec007b2fde3f963debd8fc3b69e0af86762ed3eab6b26a2cb8966660f337b2a2e4aafb7e64d7356c5461a435914a37dceafc05e1987c27e1ab7d36221e51fbc9e51ff002d243d4fd3a01ec057857c70f19c7e21d6a3d374e943e9b604e5d4e56597a161ea07407ebeb567e22fc5cbad760974ed0124b2d3dc159266389651e9c7dd1fa9fd2bca6b0c2e1a4a5ed6aee54a4ad641451457a06614514500145145001451450015f407c3fd67fb6bc356f2c8dbae61fdccd9ea5877fc460d7cff005ddfc22d5bec5afbd8c8d886f57033d9d791fa647e549ad089aba3da68a28a8320a28acdf126a234ad06faf720343112b9fef1e17f522803c4fe236a9fda9e2bbb656cc36e7ecf1fd17aff00e3d9ae66862598962493c927bd15a1ba560a28a28185145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140054d6773259ddc17301db2c2e2453e841c8a868a047d37a6ddc7a869f6d770ff00ab9e35917db2338ab35c27c20d4bed7e1b7b473992ce42a07fb0dc8fd777e55ddd66cc1ab30af3cf8cda8791a25a58a9c35ccbb987aaa0ff00123f2af43af11f8bb7df69f157d9c1f96d6154c7fb47e63fa11f9538ee5415d9c4d1451566c145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500771f08750fb2f89dad58e12ee22b8ff00697e61fa06fcebdb2be69d0af4e9dacd8de03810ccae7e80f23f2cd7d2a082323906a646535a8b5f36f896f3edfe20d46eb39124ee57fddcf1fa62be85d6ae7ec5a3df5d6706181e41f50a4d7cd144474c28a28aa340a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800afa37c2379f6ff000ce99704e59a050c7fda0307f506be72aecbc3fe32974ad22dec959808b774f7627fad26ae4495cf4cf89171f67f05ea4c0f2eab18ff00813007f4cd780d7b5fc619bcbf0a2203feb6e517f463fd2bc5288ec10d828a28a65851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451401ebbf1ae4c693a747fde9d9bf25ff00ebd79157aafc6e6c43a3afab4a7f209fe35e554a3b110d828a28a65851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451401ea5f1bf38d17d3f7dffb4ebcb6bd57e372e61d1dbd1a51f984ff000af2aa4b6221b0514514cb0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2803d77e35c79d274e93fbb3b2fe6bffd6af22af6bf8c30f99e144703fd55ca37e8c3fad78a528ec44360a28a2996145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145007bf7c48b7fb4782f525039455907fc05813fa66bc06be97d6adbedba3df5ae326681e31f52a457cd14a2670d828a28a66814514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014515d9787fc192eaba45bdeaab112eee9ecc47f4a04dd8f72af9b7c4b67f60f106a36b8c08e770bfeee78fd315f495788fc5db1fb378abed007cb750abe7fda1f29fd00fcea626707a9c4d1451546a14514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450015f46f846cfec3e19d32dc8c32c0a587fb4464fea4d78068564751d66c6cc0c89a6543ec09e4fe59afa540006070054c8cea316bcf3e3369fe7e89697ca32d6d2ed63e8ae3fc40fcebd0eb37c49a70d5741beb2c02d34442e7fbc395fd40a94427667cdb450c0ab10c0823820f6a2b4370a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2803b8f843a7fdabc4ed74c32969116cffb4df28fd0b7e55ed95c27c20d37ec9e1b7bc75c497921607fd85e07ebbbf3aeeea1ee632776145145224f01f88da5ff0065f8aeed55710dc1fb447f46ebff008f66b99afa96386195f13451c9e9bd41a7b69960df7acad4fd625ff0af37159a7d56a7b3942ff33d1c3e17db439948f95e8afa91b45d2dbef69b647eb027f8544de1dd11bef68fa69fadaa7f8573acfa1d60fef37fecf97f31f30515f4cbf853406eba369ff840a3f90a85fc17e1c7eba3da7e0b8fe554b3da5d62ff00027ea13ee8f9b28afa31fc03e187eba4c63e9238fe4d55e4f871e176e9a7327fbb7127f56ab59e50eb17f87f98bea153ba3e7ba2bdf24f85fe1b6fbb15d27fbb31feb5564f84fa0b7ddb8d453e92a1fe6b56b3ac33eff713f51abe4786d15ed12fc22d30ff00aad46f57fde0adfd055497e0f447fd56b2ebfef5b03ffb30ad166f857f6bf064bc1d5ec791515ea52fc20ba1feab5781bfde84aff5354e5f849ad2ff00aabdd3dfeacebffb2d68b33c2bda7f992f0b557d93ce68aee26f85fe238feec76b2ffb930feb8aa337c3df13c5d74b661ea92c6dfc9ab558dc3cb69afbd10e8545f659cad15b93784bc410fdfd1af8ff00b9096fe59acf9f4ad42df3e7d85dc58fefc2cbfcc56d1ab097c324fe64b8496e8a74504104820823b1a2ac90a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28ab569a6df5e63ec765733e7fe7944cdfc850ddb702ad15d1da781bc4f758f2b43be19ff009e91f97ffa162b62d7e1478b26c799650c19ff009e9709ff00b29359bad4d6f243e57d8e128af50b6f82daebe0dc5f69b10f456763ff00a08ad4b7f82129c1b8d7517d92d49fd4b0acde2e8afb43e49763c6e8af7683e09e98b8fb46ad78ff00ee22aff3cd6843f06fc371fdf9b5297fde9947f25159bc7d15d47ece47cf3457d290fc28f09c7f7eca697fdfb87fe8455e87e1c784a2fbba3447fdf9246fe6d50f31a7d98fd933e5da2bead8fc0fe188feee87607fde8837f3ab31f857c3f1fdcd0b4b07d7ec91e7f954bcc61d22c3d933e49a2bebf4d0f494fb9a5d82fd2dd07f4a9934cb04fb9656abf48947f4a5fda4bf947ecbccf8ea8afb296da04fbb044bf44029e2341d1147e14bfb4bfbbf8ffc00f65e67c65457d9e00030060514bfb4bfbbf8ff00c00f65e67c61457d9a634230517f2a6b5bc0df7a18cfd5453fed2feefe3ff003d9799f1a515f62b69d62ff007eced9beb129fe950be89a53fdfd32c5beb6e87fa53fed25fca1ecbccf902a6b3b692f2ee0b6806e966711a8f524e057d632785f4093fd6687a5b7d6d23ff0acebef0de8360f14d67a458c1741b28f1c214afb8c5694f1d1a9251512650e5572a69b691e9fa7db5a43feae08d635f7c0c66acd145751c81451450000e0823a8abcadb9411dea8d58b57eaa7ea2bc8cdf0fed297b45bc7f23d0cbeb724f91eccb1451457cb9ed85145140051451400514514005145140051451400514514005145140114d6f0ce313451c83d1d41fe759f3f87345b8cf9da45839f536e99fcf15ab45546728fc2ec2714f7473171e02f0ccf9dfa4c4bff5cddd3f91159773f0b7c3b2e7cb5bc83feb9cd9ff00d081aeee8ade38cc44769bfbccdd0a6f78a3cc2e7e10d8367ecdaa5d47ff005d2357fe58acbb9f84178b9fb36ab6f27a799114fe44d7b22a337dd527e82a74b499ba80bf535d54f32c67495fe48c6787a0b7563e7ebaf85be22873e58b3b8ffae7363ff4202b22ebc0fe25b6cf99a45c363fe79ed93ff4126be9e4b0fefbfe42a64b4857f84b7d4d7753cc717f69239a7468746cf912eb49d46d3fe3eac2ee1ffae90b2ff3156f4ef0c6bba8e0d96917d2a9e8e2160bff007d118afad95117eeaa8fa0a75762cca76d62ae73ba4afa33e6db0f84de29ba00cb6f6d680ffcf79c7fecbbaba3b0f82372d837facc31faac1097fd491fcabdbe8aca58facf6d015389e6563f06bc3f0e0dd5cdfdcb771bd517f2033fad6fd97c38f0a5a63668f1487d6676933f83122baea2b09622acb7932b952e86759e87a55963ec7a658c18ff009e502aff00215a34515936dee505145148028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a002b9cd467f3ee9883f2afcab5b1a9cfe45b1c1f9dfe515cf57a581a5bd4672e227f6428a28af48e60a28a2800a55255811d4525149a5256609b4ee8bcac19411d0d3aaadb3e0ed3d0f4ab55f178cc33c35570e9d3d0fa4c3d655a9a9750a28a2b94dc28a28a0028a28a0028a28a0028a28a0028a28009380093ed400515623b395fa80a3deacc7651afdf258fe42b6861e72e8632af08f5338024e00c9a992d657fe1c0f7e2b51115061140fa0a7574c706bed3309629fd94514b01fc6e4fb0ab096d1274404fbf353515d11a308ec8c255672dd88060714b4515a1985145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514550d5ae7c983629f9df8fa0aba707524a289949455d999a95c7da2e4953f22f0bfe35568a2bdf845422a2ba1e7c9b93bb0a28a2a841451450014514500157217de99ee3ad53a744e51b3dbbd7066184facd3d3e25b7f91d584c47b19ebb32f5148082011d296be41ab68cfa14ee145145200a28a2800a28ab10da48fcb7c83deaa3094dda289949455db2bd4b15bc927dd5e3d4f4ad08ad638f9c6e3ea6a7aeb8613acd9cb3c57f2a29c562a39918b7b0e2ad222a0c2281f4a7515d70a7187c28e695494f761451455901451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500325758a367738551935cddcccd3ccd2377e83d055cd5aefcd7f2a33f229e4fa9aceaf5f0743923cef7671d7a9ccec828a28aed300a28a2800a28a2800a28a2800a28a28026b79369da7a1e956ab3eacc12ee1b5baf6f7af9fcd703bd7a6bd7fcff00ccf57018aff9753f97f913d145490c2f29c20e3b9ec2bc149c9d91eab692bb23ab10da3c9c9f957d4d5c82d522c13f337a9ab15db4f09d667254c4f4810c36f1c5f7464fa9eb53514576462a2ac8e47272776145145310514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400567ea977e4a79719fde30fc854f7d74b6d16e3cb9fba3d6b9e91da472ee72c4e49aeec261f9df3cb630ad539572adc6d14515eb1c61451450014514500145145001451450014514500140e0d1450069e9a12e18891b0c3f87d6b6154280140007615caa33238642430e4115bfa7deadcaed6c094751ebee2bc6af818d16e74d69fd7e07743132a9eecd9728a28ae4350a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a86eae12de22eff80f5345cce96f19790fd07735cf5d5c3dcca5dcfd07a57561b0eeabbbd8caad550565b897133cf29790f27b7a5474515eca492b2385bbeac28a28a6014514500145145001451450014514500145145001451450014a8cc8c19490c39045251401bda7dfadc00926165ffd0aaf5726090723835af61a90388ee0e0f67f5fad79789c25bdea7b763aa956be923568a28af3ce90a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a82eee52da3dce724f45ee6a2bebe4b605570d2fa7a7d6b0a591e590bc8c4b1aedc3e15d4f7a5b1855aca3a2dc75ccef7121790fd07615151457ac928ab238dbbeac28a28a601451450014514500145145001451450014514500145145001451450014514500145145005db1d41edf08f978bd3b8fa56dc32a4c81e360cb5cbd4904d240fba2620ff3ae3af848d4f7a3a336a759c747b1d451542cf518e6c2c988dfdfa1abf5e54e9ca9bb491d719292ba0a28a2a0a0a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28a2800a28aad757915b0f9ce5fb28eb5518b93b4509b495d96090a0924003a935937da9f54b63f57ff000aa777792dc9f98ed4eca3a556af4e860947dea9ab396a576f4881249249c9345145779ce145145001451450014514500145145001451450014514500145145001451450014514500145145001451450014514500156ed2fe5830a4ef4fee9edf4aa9454ce119ab490e32717747476d790dc708d86fee9eb566b93abb6da94d0e039f317d1bafe75e755c0bde9b3a6188fe637e8aa96f7f04d81bb637a37156eb8650941da4ac7429296a828a28a8185145140051451400514514005145140051451400514514005145140051451400514514005145413dd4300fde3807d0726aa317276484da5b93d453cf1c0bba570a3f5359573aabb6440bb07a9e4d673bb3b16762cc7b935db4b03296b3d0c27884be1346ef5477cac0362ff0078f5ff00eb5669249249249ee68a2bd1a74a34d5a28e694dcb56145145684851451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140051451400514514005145140054f05dcd07fab738f43c8a828a99454959a04dad51af0eac0f13478f75ff000abd0ddc137dc9173e87835cd515cb3c15397c3a1b46bc96fa9d6515cc4573345feae4603d339156e3d5665fbea8ff00a1ae59606a2f85dcd96222f73728acd8f5688fdf8dd7e9cd588afade4385739f420d73ca8548ef1345522f665aa2901c8c8a5ac8b0a28a2900514514005145140051504b750c3feb1f1f81aacfaac0bf755dbf0c56b1a3527b225ce2b76685158d26af21ff00571aafd4e6aa4b7b7127de9580f45e2ba2381a8f7d0c9d78ad8e8259a3887ef1d57ea6a8cdaac4bc44ace7d7a0ac52727268ae986060be2773296224f62dcfa85c4bc6ed8be8bc554a28aec8c230568ab18b9396e14514550828a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a0028a28a00ffd9"
    info = CkbUtils.parse_spore_cell_data(data)
    assert_equal info[:content_type], "image/jpeg"
    assert_equal info[:cluster_id], nil
  end

  private

  def node_data_processor
    CkbSync::NewNodeDataProcessor.new
  end
end
