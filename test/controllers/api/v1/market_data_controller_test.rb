require "test_helper"

module Api
  module V1
    class MarketDataControllerTest < ActionDispatch::IntegrationTest
      setup do
        first_released_timestamp_addr = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323t90gna20lusyshreg32qee4fhkt9jj2t6qrqzzqxzq8yqt8kmd9")
        create(:lock_script, address: first_released_timestamp_addr, args: "0xacaf44faa7ff90242e3ca22a067354decb2ca4a5e803008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
        first_released_timestamp_other = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32s3y29vjv73cfm8qax220dwwmpdccl4upy4s9qzzqxzq8yqyd09am")
        create(:lock_script, address: first_released_timestamp_other, args: "0x448a2b24cf4709d9c1d3294f6b9db0b718fd78125605008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
        second_released_timestamp_other = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sn23uga5m8u5v87q98vr29qa8tl0ruu84gqfqzzqxzq8yqc2dxk6")
        create(:lock_script, address: second_released_timestamp_other, args: "0x4d51e23b4d9f9461fc029d835141d3afef1f387aa009008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
        third_released_timestamp_other = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sdufwedw7a0w9dkvhpsah4mdk2gkfq63e0q6qzzqxzq8yqnqq85p")
        create(:lock_script, address: third_released_timestamp_other, args: "0x3789765aef75ee2b6ccb861dbd76db291648351cbc1a008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
        second_released_timestamp_may = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn323crn7nscet5sfwxjkzhexymfa4zntzt8vasvqzzqxzq8yq92pgkg")
        create(:lock_script, address: second_released_timestamp_may, args: "0xe073f4e18cae904b8d2b0af931369ed453589676760c008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
        third_released_timestamp_may = create(:address, address_hash: "ckb1q3w9q60tppt7l3j7r09qcp7lxnp3vcanvgha8pmvsa3jplykxn32sl0qgva2l78fcnjt6x8kr8sln4lqs4twcpq4qzzqxzq8yq7hpadu")
        create(:lock_script, address: third_released_timestamp_may, args: "0x7de0433aaff8e9c4e4bd18f619e1f9d7e08556ec0415008403080720", code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
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
        create(:block, :with_block_hash, epoch: 69, timestamp: 1575090866093, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
        create(:daily_statistic, treasury_amount: "45507635189304330.674891957030103511696912093394364431189654516859837775", created_at_unixtimestamp: Time.current.yesterday.beginning_of_day.to_i)
      end

      test "should set right content type when call index" do
        create(:address, address_hash: "ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc", balance: 10**8 * 1000)
        valid_get api_v1_market_datum_url("circulating_supply")

        assert_equal "application/vnd.api+json", response.media_type
      end

      test "should return total supply that not sub treasury amount when current timestamp before first release timestamp" do
        MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-03-03")))
        valid_get api_v1_market_datum_url("total_supply")
        latest_dao = Block.recent.pick(:dao)
        parsed_dao = CkbUtils.parse_dao(latest_dao)
        result = parsed_dao.c_i - (336 * 10**16 * 0.25).to_d
        expected_total_supply = (result / 10**8).to_s

        assert_equal expected_total_supply, json
      end

      test "should return total supply that sub treasury amount when current timestamp after first release timestamp" do
        MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-06-03")))
        treasury_amount = DailyStatistic.find_by(created_at_unixtimestamp: Time.current.yesterday.beginning_of_day.to_i).treasury_amount.to_i
        valid_get api_v1_market_datum_url("total_supply")
        latest_dao = Block.recent.pick(:dao)
        parsed_dao = CkbUtils.parse_dao(latest_dao)
        result = parsed_dao.c_i - (336 * 10**16 * 0.25).to_d - treasury_amount
        expected_total_supply = (result / 10**8).to_s

        assert_equal expected_total_supply, json
      end

      test "should return current circulating supply" do
        create(:address, address_hash: "ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc", balance: 10**8 * 1000)
        valid_get api_v1_market_datum_url("circulating_supply")
        MarketData.new(indicator: "circulating_supply").call

        assert_equal MarketData.new(indicator: "circulating_supply").call.to_s, json
      end
    end
  end
end
