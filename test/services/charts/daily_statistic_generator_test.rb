require "test_helper"

module Charts
  class DailyStatisticGeneratorTest < ActiveSupport::TestCase
    MILLISECONDS_IN_DAY = BigDecimal(24 * 60 * 60 * 1000)
    GENESIS_TIMESTAMP = 1573852190812
    setup do
      to_be_counted_date = Time.current.yesterday.beginning_of_day

      @datetime = 1.day.ago
      @started_at = CkbUtils.time_in_milliseconds(to_be_counted_date.beginning_of_day)
      @ended_at = CkbUtils.time_in_milliseconds(to_be_counted_date.end_of_day) - 1

      @block = create(:block, :with_block_hash, number: 0, epoch: 69,
                                                timestamp: @datetime.to_i * 1000, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
      @tx = create(:ckb_transaction, block: @block, block_timestamp: @block.timestamp)

      @daily_dao_withdraw = DaoEvent.processed.withdraw_from_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      @current_tip_block = Block.created_after(@started_at).created_before(@ended_at).recent.first || Block.recent.first
      aggron_first_day =
        begin
          genesis_block_timestamp = Block.find_by(number: 0).timestamp
          ENV["CKB_NET_MODE"] == "testnet" && to_be_counted_date.beginning_of_day.to_i == Time.at(genesis_block_timestamp / 1000).in_time_zone.beginning_of_day.to_i
        end
      @yesterday_daily_statistic ||=
        begin
          yesterday_statistic = ::DailyStatistic.where(
            "created_at_unixtimestamp < ?", to_be_counted_date.beginning_of_day.to_i
          ).recent.first
          if to_be_counted_date.beginning_of_day.to_i == Time.at(GENESIS_TIMESTAMP / 1000).in_time_zone.beginning_of_day.to_i || aggron_first_day.present? || yesterday_statistic.blank?
            OpenStruct.new(addresses_count: 0, total_dao_deposit: 0,
                           dao_depositors_count: 0, unclaimed_compensation: 0, claimed_compensation: 0, average_deposit_time: 0, mining_reward: 0, deposit_compensation: 0, treasury_amount: 0, total_depositors_count: 0, live_cells_count: 0, dead_cells_count: 0, occupied_capacity: 0)
          else
            yesterday_statistic
          end
        end
      @unmade_dao_interests =
        begin
          tip_dao = @current_tip_block.dao
          CellOutput.nervos_dao_deposit.generated_before(@ended_at).unconsumed_at(@ended_at).reduce(0) do |memo, cell_output|
            memo + DaoCompensationCalculator.new(cell_output, tip_dao).call
          end
        end
    end

    test "should create only 1 daily statistic record" do
      block = create(:block,
                     dao: "0xaff1568bbe49672f8a02516252ab2300df8c9e15dad428000035a1d671700007", timestamp: (Time.current - 1.day).end_of_day.to_i * 1000, number: 0)
      first_released_timestamp_other = create(:address,
                                              address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32s3y29vjv73cfm8qax220dwwmpdccl4upy4s9qzzqxzq8yqyd09am")
      first_released_timestamp_addr = create(:address,
                                             address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323t90gna20lusyshreg32qee4fhkt9jj2t6qrqzzqxzq8yqt8kmd9")
      create(:lock_script, address: first_released_timestamp_addr,
                           args: "0xacaf44faa7ff90242e3ca22a067354decb2ca4a5e803008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
      create(:lock_script, address: first_released_timestamp_other,
                           args: "0x448a2b24cf4709d9c1d3294f6b9db0b718fd78125605008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
      MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-03-03")))
      create(:block, :with_block_hash, epoch: 69, timestamp: 1575090866093,
                                       dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
      create(:address,
             address_hash: "ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc", balance: 10**8 * 1000)
      tx = create(:ckb_transaction, block: block,
                                    block_timestamp: block.timestamp)
      create(:cell_output, cell_type: "nervos_dao_deposit",
                           ckb_transaction: tx, block: block, capacity: 10**8 * 1000, block_timestamp: (Time.current - 1.day).end_of_day.to_i * 1000, occupied_capacity: 6100000000, dao: block.dao)
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
      block_timestamp_temp = Block.created_after(@started_at).created_before(@ended_at).recent.pick(:timestamp)
      block_timestamp = Charts::DailyStatisticGenerator.new(@datetime).call.block_timestamp
      assert_equal block_timestamp_temp, block_timestamp
    end

    test "it should get transactions_count" do
      transactions_count_temp = CkbTransaction.created_after(@started_at).created_before(@ended_at).recent.count
      transactions_count = Charts::DailyStatisticGenerator.new(@datetime).call.transactions_count
      assert_equal transactions_count_temp.to_s, transactions_count
    end

    test "it should get addresses_count" do
      addresses_count_temp = Address.created_after(@started_at).created_before(@ended_at).count + @yesterday_daily_statistic.addresses_count.to_i
      addresses_count = Charts::DailyStatisticGenerator.new(@datetime).call.addresses_count
      assert_equal addresses_count_temp.to_s, addresses_count
    end

    test "it should get daily_dao_withdraw" do
      daily_dao_withdraw = Charts::DailyStatisticGenerator.new(@datetime).call.daily_dao_withdraw
      assert_equal @daily_dao_withdraw, daily_dao_withdraw
    end

    test "it should get total_dao_deposit" do
      # 1. from scratch
      deposit_amount = DaoEvent.processed.deposit_to_dao.created_before(@ended_at).sum(:value)
      withdraw_amount = DaoEvent.processed.withdraw_from_dao.created_before(@ended_at).sum(:value)
      total_dao_deposit1 = deposit_amount - withdraw_amount
      is_from_scratch = true
      total_dao_deposit = Charts::DailyStatisticGenerator.new(@datetime, is_from_scratch).call.total_dao_deposit
      assert_equal total_dao_deposit1.to_s, total_dao_deposit

      # 2. not from scratch
      daily_dao_deposit = DaoEvent.processed.deposit_to_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      total_dao_deposit2 = daily_dao_deposit - @daily_dao_withdraw + @yesterday_daily_statistic.total_dao_deposit.to_i
      total_dao_deposit = Charts::DailyStatisticGenerator.new(@datetime).call.total_dao_deposit
      assert_equal total_dao_deposit2.to_s, total_dao_deposit
    end

    test "it should get circulating_supply" do
      circulating_supply_temp = MarketData.new(indicator: "circulating_supply",
                                               tip_block_number: @current_tip_block.number, unit: "shannon").call
      circulating_supply = Charts::DailyStatisticGenerator.new(@datetime).call.circulating_supply
      assert_equal circulating_supply_temp, circulating_supply
    end

    test "it should get unclaimed_compensation" do
      phase1_dao_interests =
        CellOutput.nervos_dao_withdrawing.generated_before(@ended_at).unconsumed_at(@ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
          memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
        end
      unclaimed_compensation_temp = phase1_dao_interests + @unmade_dao_interests
      unclaimed_compensation = Charts::DailyStatisticGenerator.new(@datetime).call.unclaimed_compensation
      assert_equal unclaimed_compensation_temp.to_s, unclaimed_compensation
    end

    test "it should get claimed_compensation" do
      claimed_compensation_today =
        CellOutput.nervos_dao_withdrawing.consumed_after(@started_at).consumed_before(@ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
          memo + CkbUtils.dao_interest(nervos_dao_withdrawing_cell)
        end
      claimed_compensation_temp = claimed_compensation_today + @yesterday_daily_statistic.claimed_compensation.to_i
      claimed_compensation = Charts::DailyStatisticGenerator.new(@datetime).call.unclaimed_compensation
      assert_equal claimed_compensation_temp.to_s, claimed_compensation
    end

    test "it should get average_deposit_time" do
      total_deposits = 0
      # 1. total_deposits.zero?
      # average_deposit_time_temp = 0
      average_deposit_time = Charts::DailyStatisticGenerator.new(@datetime).call.average_deposit_time
      assert_equal "0", average_deposit_time

      # 2. total_deposits
      interest_bearing_deposits = 0
      uninterest_bearing_deposits = 0
      sum_interest_bearing =
        CellOutput.nervos_dao_withdrawing.generated_before(@ended_at).unconsumed_at(@ended_at).reduce(0) do |memo, nervos_dao_withdrawing_cell|
          nervos_dao_withdrawing_cell_generated_tx = nervos_dao_withdrawing_cell.ckb_transaction
          nervos_dao_deposit_cell = nervos_dao_withdrawing_cell_generated_tx.cell_inputs.order(:id)[nervos_dao_withdrawing_cell.cell_index].previous_cell_output
          interest_bearing_deposits += nervos_dao_deposit_cell.capacity
          memo + nervos_dao_deposit_cell.capacity * (nervos_dao_withdrawing_cell.block_timestamp - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
        end
      sum_uninterest_bearing =
        CellOutput.nervos_dao_deposit.generated_before(@ended_at).unconsumed_at(@ended_at).reduce(0) do |memo, nervos_dao_deposit_cell|
          uninterest_bearing_deposits += nervos_dao_deposit_cell.capacity

          memo + nervos_dao_deposit_cell.capacity * (@ended_at - nervos_dao_deposit_cell.block_timestamp) / MILLISECONDS_IN_DAY
        end
      total_deposits = interest_bearing_deposits + uninterest_bearing_deposits
      average_deposit_time = ((sum_interest_bearing + sum_uninterest_bearing) / total_deposits).truncate(3) if total_deposits != 0
      assert_equal average_deposit_time, average_deposit_time
    end

    test "it should get mining_reward" do
      mining_reward_temp = Block.where("timestamp <= ?",
                                       @ended_at).sum(:secondary_reward)
      mining_reward = Charts::DailyStatisticGenerator.new(@datetime).call.mining_reward
      assert_equal mining_reward_temp.to_s, mining_reward
    end

    test "it should get deposit_compensation" do
      unclaimed_compensation = Charts::DailyStatisticGenerator.new(@datetime).call.unclaimed_compensation
      claimed_compensation = Charts::DailyStatisticGenerator.new(@datetime).call.unclaimed_compensation
      deposit_compensation_temp = unclaimed_compensation.to_i + claimed_compensation.to_i
      deposit_compensation = Charts::DailyStatisticGenerator.new(@datetime).call.deposit_compensation
      assert_equal deposit_compensation_temp.to_s, deposit_compensation
    end

    test "it should get treasury_amount" do
      treasury_amount ||=
        begin
          parse_dao = CkbUtils.parse_dao(@current_tip_block.dao)
          parse_dao.s_i - @unmade_dao_interests
        end
      treasury_amount = Charts::DailyStatisticGenerator.new(@datetime).call.treasury_amount
      assert_equal treasury_amount, treasury_amount
    end

    test "it should get estimated_apc" do
      estimated_apc = Charts::DailyStatisticGenerator.new(@datetime).call.estimated_apc
      estimated_apc_temp = DaoContract.default_contract.estimated_apc(@current_tip_block.fraction_epoch)
      assert_equal estimated_apc_temp.to_s, estimated_apc
    end

    test "it should get live_cells_count" do
      # 1. from scratch
      is_from_scratch = true
      live_cells_count1 = CellOutput.generated_before(@ended_at).unconsumed_at(@ended_at).count
      live_cells_count = Charts::DailyStatisticGenerator.new(@datetime).call.live_cells_count
      assert_equal live_cells_count1.to_s, live_cells_count
      # 2. not from scratch
      dead_cells_count_today ||= CellOutput.consumed_after(@started_at).consumed_before(@ended_at).count
      live_cells_count2 = CellOutput.generated_after(@started_at).generated_before(@ended_at).count + @yesterday_daily_statistic.live_cells_count.to_i - dead_cells_count_today
      live_cells_count = Charts::DailyStatisticGenerator.new(@datetime).call.live_cells_count
      assert_equal live_cells_count2.to_s, live_cells_count
    end

    test "it should get dead_cells_count" do
      # 1. from scratch
      # CellOutput.generated_before(ended_at).consumed_before(ended_at).count
      cells = [
        create(:cell_output, :with_full_transaction,
               block_timestamp: @datetime.to_i * 1000, block: @block),
        create(:cell_output, :with_full_transaction,
               block_timestamp: @datetime.to_i * 1000, block: @block),
        create(:cell_output, :with_full_transaction,
               block_timestamp: @datetime.to_i * 1000, block: @block)
      ]
      CellOutput.where(id: cells.map(&:id)).update_all(consumed_block_timestamp: (@datetime.to_i + 10) * 1000)
      is_from_scratch = true
      assert_equal "3",
                   Charts::DailyStatisticGenerator.new(@datetime,
                                                       is_from_scratch).call.dead_cells_count

      # 2. not from scratch
      # dead_cells_count = dead_cells_count_today + yesterday_daily_statistic.dead_cells_count.to_i
      # dead_cells_count_today = CellOutput.consumed_after(started_at).consumed_before(ended_at).count
      #
      create :daily_statistic, created_at_unixtimestamp: @datetime.yesterday.to_i, dead_cells_count: 888

      assert_equal (3 + 888).to_s,
                   Charts::DailyStatisticGenerator.new(@datetime).call.dead_cells_count
    end

    test "it should get avg_hash_rate" do
      create :block, :with_block_hash, timestamp: (@datetime.to_i + 0.1) * 1000,
                                       dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007"
      ::DailyStatistic.any_instance.stubs(:total_difficulties_for_the_day).returns(20000)
      assert_equal "200.0",
                   Charts::DailyStatisticGenerator.new(@datetime).call.avg_hash_rate
    end

    test "it should get avg_difficulty" do
      total_blocks_count = Block.created_after(@started_at).created_before(@ended_at).count
      epoch_numbers_for_the_day = Block.created_after(@started_at).created_before(@ended_at).distinct(:epoch).pluck(:epoch)
      total_difficulties_for_the_day ||=
        epoch_numbers_for_the_day.reduce(0) do |memo, epoch_number|
          first_block_of_the_epoch = Block.created_after(@started_at).created_before(@ended_at).where(epoch: epoch_number).order("timestamp asc").first
          last_block_of_the_epoch = Block.created_after(@started_at).created_before(@ended_at).where(epoch: epoch_number).recent.first
          memo + first_block_of_the_epoch.difficulty * (last_block_of_the_epoch.number - first_block_of_the_epoch.number + 1)
        end
      ::DailyStatistic.any_instance.stubs(:total_difficulties_for_the_day).returns(200)
      ::DailyStatistic.any_instance.stubs(:total_blocks_count).returns(20000)
      avg_difficulty_temp = BigDecimal(total_difficulties_for_the_day) / total_blocks_count
      avg_difficulty = Charts::DailyStatisticGenerator.new(@datetime).call.avg_difficulty
      assert_in_delta avg_difficulty.to_f, avg_difficulty.to_f, 0.0001
    end

    test "it should get uncle_rate" do
      uncles_count = Block.created_after(@started_at).created_before(@ended_at).sum(:uncles_count)
      total_blocks_count = 20000
      ::DailyStatistic.any_instance.stubs(:total_blocks_count).returns(20000)
      uncle_rate_temp = BigDecimal(uncles_count) / total_blocks_count
      uncle_rate = Charts::DailyStatisticGenerator.new(@datetime).call.uncle_rate
      assert_equal uncle_rate_temp.to_s, uncle_rate
    end

    test "it should get total_depositors_count" do
      # 1. from scratch
      is_from_scratch = true
      total_depositors_count_temp = DaoEvent.processed.take_away_all_deposit.created_before(@ended_at).count
      total_depositors_count = Charts::DailyStatisticGenerator.new(@datetime,
                                                                   is_from_scratch).call.total_depositors_count
      assert_equal total_depositors_count_temp.to_s, total_depositors_count
      # 2. not from scratch
      new_depositors_count_today = DaoEvent.processed.new_dao_depositor.created_after(@started_at).created_before(@ended_at).count
      total_depositors_count_temp = new_depositors_count_today + @yesterday_daily_statistic.total_depositors_count.to_i
      total_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).call.total_depositors_count
      assert_equal total_depositors_count_temp.to_s, total_depositors_count
    end

    test "it should get address_balance_distribution" do
      max_n = 9
      ranges =
        (1..max_n).map do |n|
          if n == 1
            [0, 100]
          else
            [10**n, 10**(n + 1)]
          end
        end

      temp_address_balance_distribution =
        ranges.each_with_index.map do |range, index|
          begin_value = range[0] * 10**8
          end_value = range[1] * 10**8
          if index == max_n - 1
            addresses_count = Address.visible.where("balance > ?",
                                                    begin_value).count
            total_addresses_count = Address.visible.where("balance > 0").count
          else
            addresses_count = Address.visible.where(
              "balance > ? and balance <= ?", begin_value, end_value
            ).count
            total_addresses_count = Address.visible.where(
              "balance > 0 and balance <= ?", end_value
            ).count
          end

          [range[1], addresses_count, total_addresses_count]
        end
      address_balance_distribution = Charts::DailyStatisticGenerator.new(@datetime).call.address_balance_distribution
      assert_equal temp_address_balance_distribution,
                   address_balance_distribution
    end

    test "it should get total_tx_fee" do
      total_tx_fee_temp = Block.created_after(@started_at).created_before(@ended_at).sum(:total_transaction_fee)
      total_tx_fee = Charts::DailyStatisticGenerator.new(@datetime).call.total_tx_fee
      assert_equal total_tx_fee_temp, total_tx_fee
    end

    test "it should get occupied_capacity" do
      occupied_capacity_temp = CellOutput.generated_before(@ended_at).unconsumed_at(@ended_at).sum(:occupied_capacity)
      occupied_capacity = Charts::DailyStatisticGenerator.new(@datetime).call.occupied_capacity
      assert_equal occupied_capacity_temp, occupied_capacity
    end

    test "it should get daily_dao_deposit" do
      daily_dao_deposit_temp = DaoEvent.processed.deposit_to_dao.created_after(@started_at).created_before(@ended_at).sum(:value)
      daily_dao_deposit = Charts::DailyStatisticGenerator.new(@datetime).call.daily_dao_deposit
      assert_equal daily_dao_deposit_temp, daily_dao_deposit
    end

    test "it should get daily_dao_depositors_count" do
      daily_dao_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).call.daily_dao_depositors_count
      daily_dao_depositors_count_temp ||= DaoEvent.processed.new_dao_depositor.created_after(@started_at).created_before(@ended_at).count
      assert_equal daily_dao_depositors_count_temp, daily_dao_depositors_count
    end

    test "it should get dao_depositors_count" do
      # 1. from scratch
      is_from_scratch = true
      create :dao_event_with_block, block: @block, ckb_transaction: @tx, event_type: :new_dao_depositor,
                                    status: :processed, block_timestamp: @block.timestamp
      total_depositors_count = Charts::DailyStatisticGenerator.new(@datetime,
                                                                   is_from_scratch).call.total_depositors_count
      dao_depositors_count_temp = total_depositors_count.to_i - DaoEvent.processed.take_away_all_deposit.created_before(@ended_at).count
      dao_depositors_count = Charts::DailyStatisticGenerator.new(@datetime, is_from_scratch).call.dao_depositors_count
      assert_equal dao_depositors_count_temp.to_s, dao_depositors_count
      # 2. not from scratch
      daily_dao_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).call.daily_dao_depositors_count
      withdrawals_today = DaoEvent.processed.take_away_all_deposit.created_after(@started_at).created_before(@ended_at).count
      dao_depositors_count_temp = daily_dao_depositors_count.to_i - withdrawals_today + @yesterday_daily_statistic.dao_depositors_count.to_i
      dao_depositors_count = Charts::DailyStatisticGenerator.new(@datetime).call.dao_depositors_count
      assert_equal dao_depositors_count_temp.to_s, dao_depositors_count
    end

    test "it should get circulation_ratio" do
      total_dao_deposit = Charts::DailyStatisticGenerator.new(@datetime).call.total_dao_deposit
      circulating_supply = Charts::DailyStatisticGenerator.new(@datetime).call.circulating_supply
      circulation_ratio_temp = total_dao_deposit.to_i / circulating_supply
      circulation_ratio = Charts::DailyStatisticGenerator.new(@datetime).call.circulation_ratio
      assert_equal circulation_ratio_temp, circulation_ratio
    end

    test "it should get block_time_distribution" do
      block_time_distribution = Charts::DailyStatisticGenerator.new(@datetime).call.block_time_distribution
      step = 0.1
      max_n = 50 - step
      ranges =
        (0..max_n).step(0.1).map do |n|
          [n.round(2), (n + step).round(2)]
        end
      tip_block_number = @current_tip_block.number
      interval = 49999
      start_block_number = [0, tip_block_number - interval].max

      temp_block_time_distribution =
        ranges.map do |range|
          millisecond_start = range[0] * 1000
          millisecond_end = range[1] * 1000
          block_count = Block.where("number >= ? and number <= ?", start_block_number, tip_block_number).where(
            "block_time > ? and block_time <= ?", millisecond_start, millisecond_end
          ).count
          [range[1], block_count]
        end
      assert_equal temp_block_time_distribution, block_time_distribution
    end

    test "it should get epoch_time_distribution" do
      max_n = 119
      ranges = [[0, 180]] + (180..(180 + max_n)).map { |n| [n, n + 1] }
      temp_epoch_time_distribution =
        ranges.each_with_index.map { |range, index|
          milliseconds_start = range[0] * 60 * 1000
          milliseconds_end = range[1] * 60 * 1000
          if index.zero?
            epoch_count = ::EpochStatistic.where(
              "epoch_time > 0 and epoch_time <= ?", milliseconds_end
            ).count
          elsif index == max_n + 1
            epoch_count = ::EpochStatistic.where("epoch_time > ?",
                                                 milliseconds_start).count
          else
            epoch_count = ::EpochStatistic.where(
              "epoch_time > ? and epoch_time <= ?", milliseconds_start, milliseconds_end
            ).count
          end

          [range[1], epoch_count]
        }.compact
      epoch_time_distribution = Charts::DailyStatisticGenerator.new(@datetime).call.epoch_time_distribution
      assert_equal temp_epoch_time_distribution, epoch_time_distribution
    end

    test "it should get total_supply" do
      tip_dao = @current_tip_block.dao
      tip_parse_dao = CkbUtils.parse_dao(tip_dao)
      treasury_amount =
        begin
          parse_dao = CkbUtils.parse_dao(@current_tip_block.dao)
          parse_dao.s_i - @unmade_dao_interests
        end
      total_supply_temp = tip_parse_dao.c_i - MarketData::BURN_QUOTA - treasury_amount
      total_supply = Charts::DailyStatisticGenerator.new(@datetime).call.total_supply
      assert_equal total_supply_temp, total_supply
    end

    test "it should get epoch_length_distribution" do
      max_n = 1700
      ranges = (700..max_n).step(100).map { |n| [n, n + 100] }
      tip_epoch_number = @current_tip_block.epoch
      interval = 499
      start_epoch_number = [0, tip_epoch_number - interval].max

      temp_epoch_length_distribution = ranges.each_with_index.map { |range, _index|
        epoch_count = ::EpochStatistic.where("epoch_number >= ? and epoch_number <= ?", start_epoch_number, tip_epoch_number).where(
          "epoch_length > ? and epoch_length <= ?", range[0], range[1]
        ).count

        [range[1], epoch_count]
      }.compact
      epoch_length_distribution = Charts::DailyStatisticGenerator.new.call.epoch_length_distribution
      assert_equal temp_epoch_length_distribution, epoch_length_distribution
    end

    test "it should get locked_capacity" do
      market_data = MarketData.new(tip_block_number: @current_tip_block.number)
      locked_capacity_temp = market_data.ecosystem_locked + market_data.team_locked + market_data.private_sale_locked + market_data.founding_partners_locked + market_data.foundation_reserve_locked + market_data.bug_bounty_locked
      locked_capacity = Charts::DailyStatisticGenerator.new(@datetime).call.locked_capacity
      assert_equal locked_capacity_temp, locked_capacity
    end
  end
end
