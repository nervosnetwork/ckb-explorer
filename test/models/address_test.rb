require "test_helper"

class AddressTest < ActiveSupport::TestCase
  setup do
    create(:table_record_count, :block_counter)
    create(:table_record_count, :ckb_transactions_counter)
    CkbSync::Api.any_instance.stubs(:get_blockchain_info).returns(OpenStruct.new(chain: "ckb_testnet"))
    GenerateStatisticsDataWorker.any_instance.stubs(:perform).returns(true)
  end

  context "associations" do
    should have_many(:account_books)
    should have_many(:ckb_transactions).
      through(:account_books)
  end

  test "address_hash should not be nil when args is empty" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.lock.instance_variable_set(:@args, "0x")

      CkbSync::NewNodeDataProcessor.new.process_block(node_block)
      block = Block.find_by(number: DEFAULT_NODE_BLOCK_NUMBER)
      address = block.contained_addresses.first

      assert_not_nil address.address_hash
    end
  end

  test ".find_or_create_address should return the address when the address_hash exists and use default lock script" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.lock.instance_variable_set(:@args, "0xabcbce98a758f130d34da522623d7e56705bddfe0dc4781bd2331211134a19a6")
      output.lock.instance_variable_set(:@code_hash, ENV["CODE_HASH"])

      CkbSync::NewNodeDataProcessor.new.process_block(node_block)

      lock_script = node_block.transactions.first.outputs.first.lock

      assert_difference "Address.count", 0 do
        Address.find_or_create_address(lock_script, node_block.header.timestamp)
      end
    end
  end

  test ".find_or_create_address should returned address's lock hash should equal with output's lock hash" do
    CkbSync::Api.any_instance.stubs(:get_epoch_by_number).returns(
      CKB::Types::Epoch.new(
        compact_target: "0x1000",
        length: "0x07d0",
        number: "0x0",
        start_number: "0x0"
      )
    )
    VCR.use_cassette("blocks/#{DEFAULT_NODE_BLOCK_NUMBER}", record: :new_episodes) do
      node_block = CkbSync::Api.instance.get_block_by_number(DEFAULT_NODE_BLOCK_NUMBER)
      create(:block, :with_block_hash, number: node_block.header.number - 1)
      tx = node_block.transactions.first
      output = tx.outputs.first
      output.lock.instance_variable_set(:@args, "0xabcbce98a758f130d34da522623d7e56705bddfe0dc4781bd2331211134a19a6")
      output.lock.instance_variable_set(:@code_hash, ENV["CODE_HASH"])

      CkbSync::NewNodeDataProcessor.new.process_block(node_block)

      lock_script = node_block.transactions.first.outputs.first.lock
      address = Address.find_or_create_address(lock_script, node_block.header.timestamp)

      assert_equal output.lock.compute_hash, address.lock_hash
    end
  end

  test "#cal_unclaimed_compensation should return phase1 dao interests and unmade dao interests" do
    CkbSync::Api.any_instance.stubs(:calculate_dao_maximum_withdraw).returns("0x48e7b453400")
    address = create(:address, is_depositor: true)
    deposit_block = create(:block, :with_block_hash, dao: "0xea43d76640436a33337e7de7ee60240035099074a869fc0000165f8ab3750207")
    deposit_tx = create(:ckb_transaction, block: deposit_block)
    previous_output_block = create(:block, :with_block_hash, dao: "0x28fbce93e82cbd2ff345ba74f2ba2300b0cd2c97f2953a000060983e29c50007")
    previous_output_tx = create(:ckb_transaction, block: previous_output_block)
    create(:cell_output, block: previous_output_block, capacity: 50000 * 10**8, ckb_transaction: previous_output_tx, tx_hash: previous_output_tx.tx_hash, generated_by: previous_output_tx, cell_type: "nervos_dao_deposit", cell_index: 0, occupied_capacity: 6100000000, dao: previous_output_block.dao)
    create(:cell_output, block: previous_output_block, capacity: 50000 * 10**8, ckb_transaction: previous_output_tx, tx_hash: previous_output_tx.tx_hash, generated_by: previous_output_tx, cell_type: "nervos_dao_deposit", cell_index: 1, occupied_capacity: 6100000000, dao: previous_output_block.dao)
    nervos_dao_withdrawing_block = create(:block, :with_block_hash, dao: "0x9a7a7ce1f34c6a332d147991f0602400aaf7346eb06bfc0000e2abc108760207", timestamp: CkbUtils.time_in_milliseconds(Time.current))
    nervos_dao_withdrawing_tx = create(:ckb_transaction, block: nervos_dao_withdrawing_block)
    create(:cell_input, block: nervos_dao_withdrawing_block, previous_output: { tx_hash: previous_output_tx.tx_hash, index: 0 }, ckb_transaction: nervos_dao_withdrawing_tx)
    create(:cell_input, block: nervos_dao_withdrawing_block, previous_output: { tx_hash: previous_output_tx.tx_hash, index: 1 }, ckb_transaction: nervos_dao_withdrawing_tx)
    create(:cell_output, block: nervos_dao_withdrawing_block, address: address, cell_type: "nervos_dao_withdrawing", ckb_transaction: nervos_dao_withdrawing_tx, capacity: 10000 * 10**8, generated_by: nervos_dao_withdrawing_tx, occupied_capacity: 6100000000, cell_index: 0, dao: nervos_dao_withdrawing_block.dao)
    create(:cell_output, block: nervos_dao_withdrawing_block, address: address, cell_type: "nervos_dao_withdrawing", ckb_transaction: nervos_dao_withdrawing_tx, capacity: 20000 * 10**8, generated_by: nervos_dao_withdrawing_tx, occupied_capacity: 6100000000, cell_index: 1, dao: nervos_dao_withdrawing_block.dao)

    deposit_cell = create(:cell_output, block: deposit_block, address: address, cell_type: "nervos_dao_deposit", capacity: 60000 * 10**8, ckb_transaction: deposit_tx, generated_by: deposit_tx, cell_index: 0, occupied_capacity: 6100000000, dao: deposit_block.dao)

    expected_phase1_dao_interests = 54220579089
    parse_dao_ar_i = 10239678363827763
    tip_dao_ar_i = 10239685510632493
    expected_unmade_dao_interests = (deposit_cell.capacity - deposit_cell.occupied_capacity).to_i * tip_dao_ar_i / parse_dao_ar_i - (deposit_cell.capacity - deposit_cell.occupied_capacity)

    assert_equal (expected_phase1_dao_interests + expected_unmade_dao_interests), address.cal_unclaimed_compensation
  end

  test "#custom_ckb_transactions should return correct ckb transactions" do
    address = create(:address)
    block = create(:block)
    ckb_transactions = create_list(:ckb_transaction, 30, block: block, address: address, contained_address_ids: [address.id])
    ckb_transactions.each do |tx|
      AccountBook.create(address: address, ckb_transaction: tx)
    end

    ckb_transaction_ids = address.account_books.select(:ckb_transaction_id).distinct
    expected_ckb_transactions = CkbTransaction.where(id: ckb_transaction_ids).recent

    assert_equal expected_ckb_transactions.pluck(:id), address.custom_ckb_transactions.recent.pluck(:id)
  end

  test "#ckb_dao_transactions should return correct ckb transactions with dao cell" do
    address = create(:address)
    address1 = create(:address)
    30.times do |number|
      block = create(:block, :with_block_hash)
      contained_address_ids = number % 2 == 0 ? [address.id] : [address1.id]
      tx = create(:ckb_transaction, block: block, tags: ["dao"], dao_address_ids: [contained_address_ids], contained_address_ids: contained_address_ids)
      AccountBook.create(address: address, ckb_transaction: tx)
      cell_type = number % 2 == 0 ? "nervos_dao_deposit" : "nervos_dao_withdrawing"
      cell_output_address = number % 2 == 0 ? address : address1
      create(:cell_output, block: block, address: cell_output_address, ckb_transaction: tx, generated_by: tx, cell_type: cell_type)
    end

    ckb_transaction_ids = address.cell_outputs.where(cell_type: %w(nervos_dao_deposit nervos_dao_withdrawing)).select("ckb_transaction_id").distinct
    expected_ckb_transactions = CkbTransaction.where(id: ckb_transaction_ids).recent

    assert_equal expected_ckb_transactions.pluck(:id), address.ckb_dao_transactions.recent.pluck(:id)
  end

  test "#ckb_dao_transactions should return an empty array when there aren't dao cell" do
    address = create(:address)

    assert_equal [], address.ckb_dao_transactions.recent.pluck(:id)
  end

  test "#ckb_udt_transactions should return correct ckb transactions with udt cell when there are udt cells" do
    udt = create(:udt)
    address = create(:address)
    30.times do |number|
      block = create(:block, :with_block_hash)
      if number % 2 == 0
        tx = create(:ckb_transaction, block: block, tags: ["udt"], contained_udt_ids: [udt.id], udt_address_ids: [address.id], contained_address_ids: [address.id])
        create(:cell_output, block: block, ckb_transaction: tx, cell_type: "udt", type_hash: udt.type_hash, generated_by: tx, address: address)
      else
        tx = create(:ckb_transaction, block: block, tags: ["udt"], contained_udt_ids: [udt.id], udt_address_ids: [address.id], contained_address_ids: [address.id])
        tx1 = create(:ckb_transaction, block: block, tags: ["udt"], contained_udt_ids: [udt.id], udt_address_ids: [address.id], contained_address_ids: [address.id])
        create(:cell_output, block: block, ckb_transaction: tx1, cell_type: "udt", type_hash: udt.type_hash, generated_by: tx1, address: address)
        create(:cell_output, block: block, ckb_transaction: tx, cell_type: "udt", type_hash: udt.type_hash, generated_by: tx, consumed_by_id: tx1, address: address)
      end
    end

    sql =
      <<-SQL
        SELECT
          generated_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          address_id = #{address.id}
          AND
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{udt.type_hash}'

        UNION

        SELECT
          consumed_by_id ckb_transaction_id
        FROM
          cell_outputs
        WHERE
          address_id = #{address.id}
          AND
          cell_type = #{CellOutput::cell_types['udt']}
          AND
          type_hash = '#{udt.type_hash}'
          AND
          consumed_by_id is not null
      SQL
    ckb_transaction_ids = CellOutput.select("ckb_transaction_id").from("(#{sql}) as cell_outputs")
    expected_ckb_transactions = CkbTransaction.where(id: ckb_transaction_ids.distinct).recent

    assert_equal expected_ckb_transactions.pluck(:id), address.ckb_udt_transactions(udt.id).recent.pluck(:id)
  end

  test "#ckb_udt_transactions should return an empty array when there aren't udt cells" do
    udt = create(:udt)
    address = create(:address)

    assert_equal [], address.ckb_udt_transactions(udt.id)
  end

  test "#ckb_udt_transactions should return an empty array when udt not exist" do
    address = create(:address)

    assert_equal [], address.ckb_udt_transactions(123)
  end

  test "cached find cache key is lock_hash for short payload address" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    lock_script = CKB::Types::Script.new(code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", hash_type: "type", args: "0xdde7801c073dfb3464c7b1f05b806bb2bbb84e99")
    addr = CKB::Address.new(lock_script).generate
    address = Address.find_or_create_address(lock_script, Time.current.to_i)
    address = Address.cached_find(addr)
    assert_equal address, Rails.cache.realize("Address/#{lock_script.compute_hash}")
  end

  test "cached find cache key is lock_hash for full payload address" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    lock_script = CKB::Types::Script.new(code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", hash_type: "type", args: "0xdde7801c073dfb3464c7b1f05b806bb2bbb84e99")
    addr = CKB::Address.new(lock_script).send(:generate_full_payload_address)
    Address.find_or_create_address(lock_script, Time.current.to_i)
    address = Address.cached_find(addr)
    assert_equal address, Rails.cache.realize("Address/#{lock_script.compute_hash}")
  end

  test "cached find returned address's query address should be short payload address when query key is short payload address" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    lock_script = CKB::Types::Script.new(code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", hash_type: "type", args: "0xdde7801c073dfb3464c7b1f05b806bb2bbb84e99")
    addr = CKB::Address.new(lock_script).generate
    full_addr = CKB::Address.new(lock_script).send(:generate_full_payload_address)
    Address.find_or_create_address(lock_script, Time.current.to_i)
    Address.cached_find(full_addr)
    address = Address.cached_find(addr)

    assert_equal addr, address.query_address
  end

  test "cached find returned address's query address should be short payload address when query key is full payload address" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    lock_script = CKB::Types::Script.new(code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", hash_type: "type", args: "0xdde7801c073dfb3464c7b1f05b806bb2bbb84e99")
    addr = CKB::Address.new(lock_script).generate
    full_addr = CKB::Address.new(lock_script).send(:generate_full_payload_address)
    Address.find_or_create_address(lock_script, Time.current.to_i)
    Address.cached_find(addr)
    address = Address.cached_find(full_addr)

    assert_equal full_addr, address.query_address
  end

  test "cached find should return nil when query key is a hex string and there is no matched record" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    address = Address.cached_find("0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8")

    assert_nil address
  end

  test "cached find should return null address when there is no matched record" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    lock_script = CKB::Types::Script.new(code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", hash_type: "type", args: "0xdde7801c073dfb3464c7b1f05b806bb2bbb84e99")
    addr = CKB::Address.new(lock_script).generate
    address = Address.cached_find(addr)
    expected_address = NullAddress.new(addr)
    assert_equal expected_address.query_address, address.query_address
  end

  test "cached find should returned corresponding address when query key is hex string and there is a matched record" do
    redis_cache_store = ActiveSupport::Cache.lookup_store(:redis_cache_store)
    Rails.stubs(:cache).returns(redis_cache_store)
    Rails.cache.extend(CacheRealizer)
    lock_script = CKB::Types::Script.new(code_hash: "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8", hash_type: "type", args: "0xdde7801c073dfb3464c7b1f05b806bb2bbb84e99")
    full_addr = CKB::Address.new(lock_script).send(:generate_full_payload_address)
    address = Address.find_or_create_address(lock_script, Time.current.to_i)
    actual_address = Address.cached_find(lock_script.compute_hash)

    assert_equal address, actual_address
  end

  test "tx_list_cache_key should return right key" do
    addr = create(:address)
    assert_equal "Address/txs/#{addr.id}", addr.tx_list_cache_key
  end
end
