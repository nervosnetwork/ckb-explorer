require "test_helper"

module Charts
  class DailyStatisticGeneratorTest < ActiveSupport::TestCase

    MILLISECONDS_IN_DAY = BigDecimal(24 * 60 * 60 * 1000)
    GENESIS_TIMESTAMP = 1573852190812
    setup do

      to_be_counted_date = Time.current.yesterday.beginning_of_day

      @started_at = CkbUtils.time_in_milliseconds(to_be_counted_date.beginning_of_day)
      @ended_at = CkbUtils.time_in_milliseconds(to_be_counted_date.end_of_day) - 1

      @block = create(:block, :with_block_hash, number: 0, epoch: 69, timestamp: 1575090866093, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
      @daily_statistic = create(:daily_statistic, created_at_unixtimestamp: Time.current.yesterday.yesterday.beginning_of_day.to_i)
      @daily_dao_withdraw = DaoEvent.processed.withdraw_from_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      @current_tip_block = Block.created_after(@started_at).created_before(@ended_at).recent.first || Block.recent.first
      aggron_first_day =
        begin
          genesis_block_timestamp = Block.find_by(number: 0).timestamp
          ENV["CKB_NET_MODE"] == "testnet" && to_be_counted_date.beginning_of_day.to_i == Time.at(genesis_block_timestamp / 1000).in_time_zone.beginning_of_day.to_i
        end
      @yesterday_daily_statistic ||=
        begin
          yesterday_statistic = ::DailyStatistic.where("created_at_unixtimestamp < ?", to_be_counted_date.beginning_of_day.to_i).recent.first
          if to_be_counted_date.beginning_of_day.to_i == Time.at(GENESIS_TIMESTAMP / 1000).in_time_zone.beginning_of_day.to_i || aggron_first_day.present? || yesterday_statistic.blank?
            OpenStruct.new(addresses_count: 0, total_dao_deposit: 0, dao_depositors_count: 0, unclaimed_compensation: 0, claimed_compensation: 0, average_deposit_time: 0, mining_reward: 0, deposit_compensation: 0, treasury_amount: 0, total_depositors_count: 0, live_cells_count: 0, dead_cells_count: 0, occupied_capacity: 0)
          else
            yesterday_statistic
          end
        end
    end

    test "should create only 1 daily statistic record" do
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
      Charts::DailyStatisticGenerator.new(@datetime).call
      assert_equal count + 1, ::DailyStatistic.count

      Charts::DailyStatisticGenerator.new(@datetime).call
      assert_equal count + 1, ::DailyStatistic.count
    end

    test "it should get block_timestamp" do
      block_timestamp = Block.created_after(@started_at).created_before(@ended_at).recent.pick(:timestamp)
      block_timestamp_update = Charts::DailyStatisticGenerator.new(@datetime).block_timestamp
      @daily_statistic.update block_timestamp: block_timestamp_update
      assert_equal block_timestamp, @daily_statistic.block_timestamp
    end

    test "it should get transactions_count" do
      transactions_count = CkbTransaction.created_after(@started_at).created_before(@ended_at).recent.count
      transactions_count_update = Charts::DailyStatisticGenerator.new(@datetime).transactions_count
      @daily_statistic.update transactions_count: transactions_count_update
      assert_equal transactions_count, @daily_statistic.transactions_count.to_i
    end

    test "it should get addresses_count" do
      addresses_count = Address.created_after(@started_at).created_before(@ended_at).count + @yesterday_daily_statistic.addresses_count.to_i
      addresses_count_update = Charts::DailyStatisticGenerator.new(@datetime).addresses_count
      @daily_statistic.update addresses_count: addresses_count_update
      assert_equal addresses_count, @daily_statistic.addresses_count.to_i
    end

    test "it should get daily_dao_withdraw" do
      daily_dao_withdraw_update = Charts::DailyStatisticGenerator.new.daily_dao_withdraw
      @daily_statistic.update daily_dao_withdraw: daily_dao_withdraw_update
      assert_equal @daily_dao_withdraw, @daily_statistic.daily_dao_withdraw
    end

    test "it should get total_dao_deposit" do
      deposit_amount = DaoEvent.processed.deposit_to_dao.created_before(@ended_at).sum(:value)
      withdraw_amount = DaoEvent.processed.withdraw_from_dao.created_before(@ended_at).sum(:value)
      total_dao_deposit1 = deposit_amount - withdraw_amount
      daily_dao_deposit = DaoEvent.processed.deposit_to_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      total_dao_deposit2 = daily_dao_deposit - @daily_dao_withdraw + @yesterday_daily_statistic.total_dao_deposit.to_i
      total_dao_deposit_update = Charts::DailyStatisticGenerator.new(@datetime).total_dao_deposit
      @daily_statistic.update total_dao_deposit: total_dao_deposit_update
      assert total_dao_deposit1 == @daily_statistic.total_dao_deposit.to_i || total_dao_deposit2 == @daily_statistic.total_dao_deposit.to_i
    end

    test "it should get circulating_supply" do
      circulating_supply = @daily_statistic.circulating_supply
      circulating_supply_update = Charts::DailyStatisticGenerator.new(@datetime).circulating_supply
      @daily_statistic.update circulating_supply: circulating_supply_update
      assert circulating_supply != @daily_statistic.circulating_supply
    end

    test "it should get unclaimed_compensation" do
      unclaimed_compensation_update = Charts::DailyStatisticGenerator.new(@datetime).unclaimed_compensation
      unclaimed_compensation = Charts::DailyStatisticGenerator.new(@datetime).unclaimed_compensation
      @daily_statistic.update unclaimed_compensation: unclaimed_compensation_update
      assert_equal unclaimed_compensation.to_s, @daily_statistic.unclaimed_compensation
    end

    test "it should get claimed_compensation" do
      claimed_compensation_update = Charts::DailyStatisticGenerator.new(@datetime).claimed_compensation
      claimed_compensation_today =
        CellOutput.nervos_dao_withdrawing.consumed_after(@started_at).consumed_before(@ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
          memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
        end
      claimed_compensation = claimed_compensation_today + @yesterday_daily_statistic.claimed_compensation.to_i
      @daily_statistic.update claimed_compensation: claimed_compensation_update
      assert_equal claimed_compensation, @daily_statistic.claimed_compensation.to_i
    end

    test "it should get average_deposit_time" do
      average_deposit_time_update = Charts::DailyStatisticGenerator.new(@datetime).average_deposit_time
      average_deposit_time = Charts::DailyStatisticGenerator.new(@datetime).average_deposit_time
      @daily_statistic.update average_deposit_time: average_deposit_time_update
      assert_equal average_deposit_time, @daily_statistic.average_deposit_time.to_i
    end

    test "it should get mining_reward" do
      mining_reward = Block.where("timestamp <= ?", @ended_at).sum(:secondary_reward)
      mining_reward_update = Charts::DailyStatisticGenerator.new(@datetime).mining_reward
      @daily_statistic.update mining_reward: mining_reward_update
      assert_equal mining_reward, @daily_statistic.mining_reward.to_i
    end

    test "it should get deposit_compensation" do
      deposit_compensation_update = Charts::DailyStatisticGenerator.new(@datetime).deposit_compensation
      deposit_compensation = Charts::DailyStatisticGenerator.new(@datetime).deposit_compensation
      assert_equal deposit_compensation, @daily_statistic.deposit_compensation.to_i
    end

    test "it should get treasury_amount" do
      treasury_amount_update = Charts::DailyStatisticGenerator.new(@datetime).treasury_amount
      treasury_amount = Charts::DailyStatisticGenerator.new(@datetime).treasury_amount
      @daily_statistic.update treasury_amount: treasury_amount_update
      assert_equal treasury_amount, @daily_statistic.treasury_amount.to_i
    end

    test "it should get estimated_apc" do
      estimated_apc_update = Charts::DailyStatisticGenerator.new(@datetime).estimated_apc
      estimated_apc = Charts::DailyStatisticGenerator.new(@datetime).estimated_apc
      @daily_statistic.update estimated_apc: estimated_apc_update
      assert_equal format("%.4f", estimated_apc).to_f.to_s, @daily_statistic.estimated_apc
    end

    test "it should get live_cells_count" do
      live_cells_count_update = Charts::DailyStatisticGenerator.new(@datetime).live_cells_count
      live_cells_count = Charts::DailyStatisticGenerator.new(@datetime).live_cells_count
      @daily_statistic.update live_cells_count: live_cells_count_update
      assert_equal live_cells_count, @daily_statistic.live_cells_count.to_i
    end

    test "it should get dead_cells_count" do

      # 1. from scratch
      # CellOutput.generated_before(ended_at).consumed_before(ended_at).count
      datetime = 1.day.ago
      block = create :block, :with_block_hash, timestamp: datetime.to_i * 1000
      create :cell_output,:with_full_transaction, block_timestamp: datetime.to_i * 1000, consumed_block_timestamp: (datetime.to_i + 10) * 1000, block: block
      create :cell_output,:with_full_transaction, block_timestamp: datetime.to_i * 1000, consumed_block_timestamp: (datetime.to_i + 10) * 1000, block: block
      create :cell_output,:with_full_transaction, block_timestamp: datetime.to_i * 1000, consumed_block_timestamp: (datetime.to_i + 10) * 1000, block: block

      is_from_scratch = true
      assert_equal 3, Charts::DailyStatisticGenerator.new(datetime, is_from_scratch).dead_cells_count

      # 2. not from scratch
      # dead_cells_count = dead_cells_count_today + yesterday_daily_statistic.dead_cells_count.to_i
      # dead_cells_count_today = CellOutput.consumed_after(started_at).consumed_before(ended_at).count
      #
      assert_equal 3, Charts::DailyStatisticGenerator.new(datetime).send(:dead_cells_count_today)

      daily_statistic = DailyStatistic.new
      Charts::DailyStatisticGenerator.any_instance.stubs(:yesterday_daily_statistic).returns(daily_statistic)
      DailyStatistic.any_instance.stubs(:dead_cells_count).returns(888)

      assert_equal (3 + 888), Charts::DailyStatisticGenerator.new(datetime).dead_cells_count
    end

    test "it should get avg_hash_rate" do
      datetime = 1.day.ago
      create :block, :with_block_hash, timestamp: datetime.to_i * 1000
      create :block, :with_block_hash, timestamp: (datetime.to_i + 0.1) * 1000
      Charts::DailyStatisticGenerator.any_instance.stubs(:total_difficulties_for_the_day).returns(20000)
      assert_equal 200, Charts::DailyStatisticGenerator.new(datetime).avg_hash_rate
    end

    test "it should get avg_difficulty" do
      avg_difficulty_update = Charts::DailyStatisticGenerator.new(@datetime).avg_difficulty
      avg_difficulty = Charts::DailyStatisticGenerator.new(@datetime).avg_difficulty
      @daily_statistic.update avg_difficulty: avg_difficulty_update
      assert_equal avg_difficulty.to_s, @daily_statistic.avg_difficulty
    end

    test "it should get uncle_rate" do
      uncle_rate_update = Charts::DailyStatisticGenerator.new(@datetime).uncle_rate
      uncle_rate = Charts::DailyStatisticGenerator.new(@datetime).uncle_rate
      @daily_statistic.update uncle_rate: uncle_rate_update
      assert_equal uncle_rate.to_s, @daily_statistic.uncle_rate
    end

    test "it should get total_depositors_count" do
      total_depositors_count_update = Charts::DailyStatisticGenerator.new(@datetime).avg_difficulty
      @daily_statistic.update total_depositors_count: total_depositors_count_update
      total_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).avg_difficulty
      assert_equal total_depositors_count.to_s, @daily_statistic.total_depositors_count
    end

    test "it should get address_balance_distribution" do
      address_balance_distribution = Charts::DailyStatisticGenerator.new(@datetime).address_balance_distribution
      temp_address_balance_distribution = Charts::DailyStatisticGenerator.new(@datetime).address_balance_distribution
      @daily_statistic.update address_balance_distribution: address_balance_distribution
      assert_equal temp_address_balance_distribution, @daily_statistic.address_balance_distribution
    end

    test "it should get total_tx_fee" do
      total_tx_fee = Block.created_after(@started_at).created_before(@ended_at).sum(:total_transaction_fee)
      total_tx_fee_update = Charts::DailyStatisticGenerator.new(@datetime).total_tx_fee
      @daily_statistic.update total_tx_fee: total_tx_fee_update
      assert_equal total_tx_fee, @daily_statistic.total_tx_fee
    end

    test "it should get occupied_capacity" do
      occupied_capacity = CellOutput.generated_before(@ended_at).unconsumed_at(@ended_at).sum(:occupied_capacity)
      occupied_capacity_update = Charts::DailyStatisticGenerator.new(@datetime).occupied_capacity
      @daily_statistic.update occupied_capacity: occupied_capacity_update
      assert_equal occupied_capacity, @daily_statistic.occupied_capacity
    end

    test "it should get daily_dao_deposit" do
      daily_dao_deposit = DaoEvent.processed.deposit_to_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      daily_dao_deposit_update = Charts::DailyStatisticGenerator.new.daily_dao_deposit
      @daily_statistic.update daily_dao_deposit: daily_dao_deposit_update
      assert_equal daily_dao_deposit, @daily_statistic.daily_dao_deposit
    end

    test "it should get daily_dao_depositors_count" do
      daily_dao_depositors_count_update = Charts::DailyStatisticGenerator.new(@datetime).daily_dao_depositors_count
      daily_dao_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).daily_dao_depositors_count
      @daily_statistic.update daily_dao_depositors_count: daily_dao_depositors_count_update
      assert_equal daily_dao_depositors_count, @daily_statistic.daily_dao_depositors_count
    end

    test "it should get dao_depositors_count" do
      dao_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).dao_depositors_count
      dao_depositors_count_update = Charts::DailyStatisticGenerator.new(@datetime).dao_depositors_count
      @daily_statistic.update dao_depositors_count: dao_depositors_count_update.to_s
      assert_equal dao_depositors_count.to_s, @daily_statistic.dao_depositors_count
    end

    test "it should get circulation_ratio" do
      circulation_ratio_update = Charts::DailyStatisticGenerator.new(@datetime).circulation_ratio
      circulation_ratio = Charts::DailyStatisticGenerator.new(@datetime).circulation_ratio
      @daily_statistic.update circulation_ratio: circulation_ratio_update
      assert_equal circulation_ratio, @daily_statistic.circulation_ratio
    end

    test "it should get block_time_distribution" do
      block_time_distribution = Charts::DailyStatisticGenerator.new(@datetime).block_time_distribution
      temp_block_time_distribution = Charts::DailyStatisticGenerator.new(@datetime).block_time_distribution
      @daily_statistic.update block_time_distribution: block_time_distribution
      assert_equal temp_block_time_distribution, @daily_statistic.block_time_distribution
    end

    test "it should get epoch_time_distribution" do
      epoch_time_distribution = Charts::DailyStatisticGenerator.new(@datetime).epoch_time_distribution
      temp_epoch_time_distribution = Charts::DailyStatisticGenerator.new(@datetime).epoch_time_distribution
      @daily_statistic.update epoch_time_distribution: epoch_time_distribution
      assert_equal temp_epoch_time_distribution, @daily_statistic.epoch_time_distribution
    end

    test "it should get total_supply" do
      unmade_dao_interests =
        begin
          tip_dao = @current_tip_block.dao
          CellOutput.nervos_dao_deposit.generated_before(@ended_at).unconsumed_at(@ended_at).reduce(0) do |memo, cell_output|
            memo + DaoCompensationCalculator.new(cell_output, tip_dao).call
          end
        end
      tip_dao = @current_tip_block.dao
      tip_parse_dao = CkbUtils.parse_dao(tip_dao)
      treasury_amount =
        begin
          parse_dao = CkbUtils.parse_dao(@current_tip_block.dao)
          parse_dao.s_i - unmade_dao_interests
        end
      total_supply = tip_parse_dao.c_i - MarketData::BURN_QUOTA - treasury_amount
      total_supply_update= Charts::DailyStatisticGenerator.new(@datetime).total_supply
      assert_equal total_supply, total_supply_update
    end

    test "it should get epoch_length_distribution" do
      epoch_length_distribution = Charts::DailyStatisticGenerator.new.epoch_length_distribution
      temp_epoch_length_distribution = Charts::DailyStatisticGenerator.new.epoch_length_distribution
      @daily_statistic.update epoch_length_distribution: epoch_length_distribution
      assert_equal temp_epoch_length_distribution, @daily_statistic.epoch_length_distribution
    end

    test "it should get locked_capacity" do
      locked_capacity = Charts::DailyStatisticGenerator.new(@datetime).locked_capacity
      temp_locked_capacity = Charts::DailyStatisticGenerator.new(@datetime).locked_capacity
      @daily_statistic.update locked_capacity: locked_capacity
      assert_equal sprintf("%.0f", temp_locked_capacity).to_i, @daily_statistic.locked_capacity
    end


  end
end
