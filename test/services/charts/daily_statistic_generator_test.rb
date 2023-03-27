require "test_helper"

module Charts
  class DailyStatisticGeneratorTest < ActiveSupport::TestCase

    setup do
      datetime = nil
      to_be_counted_date = datetime.presence || Time.current.yesterday.beginning_of_day
      @started_at = CkbUtils.time_in_milliseconds(to_be_counted_date.beginning_of_day)
      @ended_at = CkbUtils.time_in_milliseconds(to_be_counted_date.end_of_day) - 1
      @block = create(:block, :with_block_hash, number: 0, epoch: 69, timestamp: 1575090866093, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
      @daily_statistic = create(:daily_statistic, created_at_unixtimestamp: Time.current.yesterday.yesterday.beginning_of_day.to_i)
      @daily_statistic2 = create(:daily_statistic, created_at_unixtimestamp: Time.current.yesterday.yesterday.beginning_of_day.to_i)
      block = create(:block, dao: "0xaff1568bbe49672f8a02516252ab2300df8c9e15dad428000035a1d671700007", timestamp: (Time.current - 1.day).end_of_day.to_i * 1000, number: 0)
      first_released_timestamp_other = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32s3y29vjv73cfm8qax220dwwmpdccl4upy4s9qzzqxzq8yqyd09am")
      first_released_timestamp_addr = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323t90gna20lusyshreg32qee4fhkt9jj2t6qrqzzqxzq8yqt8kmd9")
      create(:lock_script, address: first_released_timestamp_addr, args: "0xacaf44faa7ff90242e3ca22a067354decb2ca4a5e803008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
      create(:lock_script, address: first_released_timestamp_other, args: "0x448a2b24cf4709d9c1d3294f6b9db0b718fd78125605008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
      MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-03-03")))
      create(:block, :with_block_hash, epoch: 69, timestamp: 1575090866093, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
      create(:address, address_hash: "ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc", balance: 10**8 * 1000)
      tx = create(:ckb_transaction, block: block, block_timestamp: block.timestamp)
      create(:cell_output, cell_type: "nervos_dao_deposit", generated_by: tx, ckb_transaction: tx, block: block, capacity: 10**8 * 1000, block_timestamp: (Time.current - 1.day).end_of_day.to_i * 1000, occupied_capacity: 6100000000, dao: block.dao)
    end

    test "should create daily statistic record" do
      CkbSync::Api.any_instance.stubs(:get_tip_header).returns(
        CKB::Types::BlockHeader.new(
          compact_target: "0x1a33cadd",
          hash: "0x661820215abf7b94d368cbfddd28c613ef035c779f2907e733101b78cdadefd2",
          number: "0x1adb0",
          parent_hash: "0xeec75d2da62a178a447975e58d26269922ea3905e545edd02c40ac414fa16760",
          nonce: "0x154d30e763c01ec10000005d25010100",
          timestamp: "0x16ebabb47ad",
          transactions_root: "0x0fc86d973cca12e6543aeb065e6909152153c8aa5111a820124fb71363478ec6",
          proposals_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
          extra_hash: "0x0000000000000000000000000000000000000000000000000000000000000000",
          version: "0x0",
          epoch: "0x70803b9000045",
          dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007"
        )
      )
      count = ::DailyStatistic.count
      Charts::DailyStatisticGenerator.new.call
      assert_equal count + 1, ::DailyStatistic.count
    end

    test "it should get total_dao_deposit" do
      Charts::DailyStatisticGenerator.new.total_dao_deposit @daily_statistic
      Charts::DailyStatisticGenerator.new.total_dao_deposit @daily_statistic2
      assert_equal @daily_statistic2.total_dao_deposit, @daily_statistic.total_dao_deposit
    end

    test "it should get total_supply" do
      Charts::DailyStatisticGenerator.new.total_supply @daily_statistic
      Charts::DailyStatisticGenerator.new.total_supply @daily_statistic2
      assert_equal @daily_statistic2.total_supply, @daily_statistic.total_supply
    end

    test "it should get circulating_supply" do
      Charts::DailyStatisticGenerator.new.circulating_supply @daily_statistic
      Charts::DailyStatisticGenerator.new.circulating_supply @daily_statistic2
      assert_equal @daily_statistic2.circulating_supply, @daily_statistic.circulating_supply
    end

    test "it should get circulation_ratio" do
      circulation_ratio = @daily_statistic.circulation_ratio
      Charts::DailyStatisticGenerator.new.circulation_ratio @daily_statistic
      assert_equal true, circulation_ratio != @daily_statistic.circulation_ratio
    end

    test "it should get unclaimed_compensation" do
      Charts::DailyStatisticGenerator.new.unclaimed_compensation @daily_statistic
      Charts::DailyStatisticGenerator.new.unclaimed_compensation @daily_statistic2
      assert_equal @daily_statistic2.unclaimed_compensation, @daily_statistic.unclaimed_compensation
    end

    test "it should get claimed_compensation" do
      Charts::DailyStatisticGenerator.new.claimed_compensation @daily_statistic
      Charts::DailyStatisticGenerator.new.claimed_compensation @daily_statistic2
      assert_equal @daily_statistic2.claimed_compensation, @daily_statistic.claimed_compensation
    end
    test "it should get deposit_compensation" do
      Charts::DailyStatisticGenerator.new.unclaimed_compensation @daily_statistic
      Charts::DailyStatisticGenerator.new.claimed_compensation @daily_statistic
      Charts::DailyStatisticGenerator.new.deposit_compensation @daily_statistic
      Charts::DailyStatisticGenerator.new.unclaimed_compensation @daily_statistic2
      Charts::DailyStatisticGenerator.new.claimed_compensation @daily_statistic2
      Charts::DailyStatisticGenerator.new.deposit_compensation @daily_statistic2
      assert_equal @daily_statistic2.deposit_compensation, @daily_statistic.deposit_compensation
    end

    test "it should get treasury_amount" do
      treasury_amount = @daily_statistic.treasury_amount
      Charts::DailyStatisticGenerator.new.treasury_amount @daily_statistic
      assert_equal true, treasury_amount != @daily_statistic.treasury_amount
    end

    test "it should get estimated_apc" do
      Charts::DailyStatisticGenerator.new.estimated_apc @daily_statistic
      Charts::DailyStatisticGenerator.new.estimated_apc @daily_statistic2
      assert_equal @daily_statistic2.estimated_apc, @daily_statistic.estimated_apc
    end

    test "it should get mining_reward" do
      mining_reward = Block.where("timestamp <= ?", @ended_at).sum(:secondary_reward)
      Charts::DailyStatisticGenerator.new.mining_reward @daily_statistic
      assert_equal mining_reward, @daily_statistic.mining_reward.to_i
    end

    test "it should get block_timestamp" do
      block_timestamp = Block.created_after(@started_at).created_before(@ended_at).recent.pick(:timestamp)
      Charts::DailyStatisticGenerator.new.block_timestamp @daily_statistic
      Charts::DailyStatisticGenerator.new.block_timestamp @daily_statistic2
      assert_equal block_timestamp, @daily_statistic.block_timestamp
      assert_equal @daily_statistic2.block_timestamp, @daily_statistic.block_timestamp
    end

    test "it should get transactions_count" do
      transactions_count = CkbTransaction.created_after(@started_at).created_before(@ended_at).recent.count
      Charts::DailyStatisticGenerator.new.transactions_count @daily_statistic
      assert_equal transactions_count, @daily_statistic.transactions_count.to_i
    end

    test "it should get daily_dao_deposit" do
      daily_dao_deposit = DaoEvent.processed.deposit_to_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      Charts::DailyStatisticGenerator.new.daily_dao_deposit @daily_statistic
      assert_equal daily_dao_deposit, @daily_statistic.daily_dao_deposit
    end

    test "it should get occupied_capacity" do
      occupied_capacity = CellOutput.generated_before(@ended_at).unconsumed_at(@ended_at).sum(:occupied_capacity)
      Charts::DailyStatisticGenerator.new.occupied_capacity @daily_statistic
      assert_equal occupied_capacity, @daily_statistic.occupied_capacity
    end

    test "it should get total_tx_fee" do
      total_tx_fee = Block.created_after(@started_at).created_before(@ended_at).sum(:total_transaction_fee)
      Charts::DailyStatisticGenerator.new.total_tx_fee @daily_statistic
      assert_equal total_tx_fee, @daily_statistic.total_tx_fee
    end

    test "it should get daily_dao_withdraw" do
      daily_dao_withdraw = DaoEvent.processed.withdraw_from_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      Charts::DailyStatisticGenerator.new.daily_dao_withdraw @daily_statistic
      assert_equal daily_dao_withdraw, @daily_statistic.daily_dao_withdraw
    end

    test "it should get average_deposit_time" do
      average_deposit_time = @daily_statistic.average_deposit_time
      Charts::DailyStatisticGenerator.new.average_deposit_time @daily_statistic
      assert_equal true, average_deposit_time != @daily_statistic.average_deposit_time
    end
    test "it should get live_cells_count" do
      live_cells_count = @daily_statistic.live_cells_count
      Charts::DailyStatisticGenerator.new.live_cells_count @daily_statistic
      assert_equal true, live_cells_count != @daily_statistic.live_cells_count
    end
    test "it should get total_depositors_count" do
      total_depositors_count = @daily_statistic.total_depositors_count
      Charts::DailyStatisticGenerator.new.avg_difficulty @daily_statistic
      assert_equal total_depositors_count, @daily_statistic.total_depositors_count
    end

    test "it should get dead_cells_count" do
      dead_cells_count = @daily_statistic.dead_cells_count
      Charts::DailyStatisticGenerator.new.dead_cells_count @daily_statistic
      assert_equal dead_cells_count, @daily_statistic.dead_cells_count
    end

    test "it should get addresses_count" do
      addresses_count = @daily_statistic.addresses_count.to_i
      Charts::DailyStatisticGenerator.new.addresses_count @daily_statistic
      assert_equal addresses_count, @daily_statistic.addresses_count.to_i
    end

    test "it should get avg_hash_rate" do
      avg_hash_rate = @daily_statistic.avg_hash_rate
      Charts::DailyStatisticGenerator.new.avg_hash_rate @daily_statistic
      assert_equal true, avg_hash_rate != @daily_statistic.avg_hash_rate
    end

    test "it should get avg_difficulty" do
      avg_difficulty = @daily_statistic.avg_difficulty
      Charts::DailyStatisticGenerator.new.avg_difficulty @daily_statistic
      assert_equal true, avg_difficulty != @daily_statistic.avg_difficulty
    end

    test "it should get address_balance_distribution" do
      address_balance_distribution = @daily_statistic.address_balance_distribution
      Charts::DailyStatisticGenerator.new.address_balance_distribution @daily_statistic
      assert_equal true, address_balance_distribution != @daily_statistic.address_balance_distribution
    end

    test "it should get daily_dao_depositors_count" do
      daily_statistic = create(:daily_statistic, created_at_unixtimestamp: Time.current.yesterday.yesterday.beginning_of_day.to_i)
      Charts::DailyStatisticGenerator.new.daily_dao_depositors_count @daily_statistic
      Charts::DailyStatisticGenerator.new.daily_dao_depositors_count daily_statistic
      assert_equal daily_statistic.daily_dao_depositors_count, @daily_statistic.daily_dao_depositors_count
    end

    test "it should get block_time_distribution" do
      block_time_distribution = @daily_statistic.block_time_distribution
      Charts::DailyStatisticGenerator.new.block_time_distribution @daily_statistic
      assert_equal true, block_time_distribution != @daily_statistic.block_time_distribution
    end

    test "it should get epoch_time_distribution" do
      epoch_time_distribution = @daily_statistic.epoch_time_distribution
      Charts::DailyStatisticGenerator.new.epoch_time_distribution @daily_statistic
      assert_equal true, epoch_time_distribution != @daily_statistic.epoch_time_distribution
    end

    test "it should get epoch_length_distribution" do
      epoch_length_distribution = @daily_statistic.epoch_length_distribution
      Charts::DailyStatisticGenerator.new.epoch_length_distribution @daily_statistic
      assert_equal true, epoch_length_distribution != @daily_statistic.epoch_length_distribution
    end

    test "it should get locked_capacity" do
      locked_capacity = @daily_statistic.locked_capacity
      Charts::DailyStatisticGenerator.new.locked_capacity @daily_statistic
      assert_equal true, locked_capacity != @daily_statistic.locked_capacity
    end

  end
end
