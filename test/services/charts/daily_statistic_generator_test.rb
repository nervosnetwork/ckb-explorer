require "test_helper"

module Charts
  class DailyStatisticGeneratorTest < ActiveSupport::TestCase
    test "should create daily statistic record" do
      block = create(:block, dao: "0xaff1568bbe49672f8a02516252ab2300df8c9e15dad428000035a1d671700007", timestamp: (Time.current - 1.day).end_of_day.to_i * 1000, number: 0)
      first_released_timestamp_other = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32s3y29vjv73cfm8qax220dwwmpdccl4upy4s9qzzqxzq8yqyd09am")
      first_released_timestamp_addr = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323t90gna20lusyshreg32qee4fhkt9jj2t6qrqzzqxzq8yqt8kmd9")
      create(:lock_script, address: first_released_timestamp_addr, args: "0xacaf44faa7ff90242e3ca22a067354decb2ca4a5e803008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
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
      create(:lock_script, address: first_released_timestamp_other, args: "0x448a2b24cf4709d9c1d3294f6b9db0b718fd78125605008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
      MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-03-03")))
      create(:block, :with_block_hash, epoch: 69, timestamp: 1575090866093, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
      create(:address, address_hash: "ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc", balance: 10**8 * 1000)
      tx = create(:ckb_transaction, block: block, block_timestamp: block.timestamp)
      create(:cell_output, cell_type: "nervos_dao_deposit", generated_by: tx, ckb_transaction: tx, block: block, capacity: 10**8 * 1000, block_timestamp: (Time.current - 1.day).end_of_day.to_i * 1000, occupied_capacity: 6100000000, dao: block.dao)
      create(:daily_statistic, created_at_unixtimestamp: Time.current.yesterday.yesterday.beginning_of_day.to_i)
      assert_difference -> { ::DailyStatistic.count }, 1 do
        Charts::DailyStatisticGenerator.new.call
      end
    end

    test "average_block_time should return 840 points" do
      1000.times do |number|
        create(:block_time_statistic, stat_timestamp: 35.days.ago.end_of_day.to_i + number)
      end
      daily_generator = Charts::DailyStatisticGenerator.new
      assert_equal 24 * 35, daily_generator.send(:average_block_time).count
    end
  end
end
