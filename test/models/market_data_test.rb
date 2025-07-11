require "test_helper"

class MarketDataTest < ActiveSupport::TestCase
  setup do
    create(:lock_script,  args: "0xacaf44faa7ff90242e3ca22a067354decb2ca4a5e803008403080720",
                          code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
    create(:lock_script,  args: "0x448a2b24cf4709d9c1d3294f6b9db0b718fd78125605008403080720",
                          code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
    create(:lock_script,  args: "0x4d51e23b4d9f9461fc029d835141d3afef1f387aa009008403080720",
                          code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
    create(:lock_script,  args: "0x3789765aef75ee2b6ccb861dbd76db291648351cbc1a008403080720",
                          code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
    create(:lock_script, args: "0xe073f4e18cae904b8d2b0af931369ed453589676760c008403080720",
                         code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
    create(:lock_script, args: "0x7de0433aaff8e9c4e4bd18f619e1f9d7e08556ec0415008403080720",
                         code_hash: "0x5c5069eb0857efc65e1bca0c07df34c31663b3622fd3876c876320fc9634e2a8")
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
        dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007",
      ),
    )
    create(:block, :with_block_hash, epoch: 69, timestamp: 1575090866093, dao: "0xeeaf2fe1baa6df2e577fda67799223009ca127a6d1e30c00002dc77aa42b0007")
  end

  test "total_supply should not sub treasury amount when current timestamp before first release timestamp" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-03-03")))
    latest_dao = Block.recent.pick(:dao)
    parsed_dao = CkbUtils.parse_dao(latest_dao)
    result = parsed_dao.c_i - (336 * (10**16) * 0.25).to_d
    expected_circulating_supply = result / (10**8)

    assert_equal expected_circulating_supply, MarketData.new.send(:total_supply)
  end

  test "total_supply should sub treasury amount when current timestamp after first release timestamp" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-06-03")))
    latest_dao = Block.recent.pick(:dao)
    parsed_dao = CkbUtils.parse_dao(latest_dao)
    result = parsed_dao.c_i - (336 * (10**16) * 0.25).to_d - parsed_dao.s_i
    expected_circulating_supply = result / (10**8)

    assert_equal expected_circulating_supply, MarketData.new.send(:total_supply)
  end

  test "circulating_supply should return right value" do
    bug_bounty_address = create(:address, address_hash: "ckb1qyqy6mtud5sgctjwgg6gydd0ea05mr339lnslczzrc", balance: (10**8) * 1000)
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2019-11-30")))
    latest_dao = Block.recent.pick(:dao)
    parsed_dao = CkbUtils.parse_dao(latest_dao)
    result = parsed_dao.c_i - parsed_dao.s_i - MarketData::BURN_QUOTA - (MarketData::ECOSYSTEM_QUOTA * 0.97) -
      (MarketData::TEAM_QUOTA * (2 / BigDecimal("3"))) - (MarketData::PRIVATE_SALE_QUOTA * (1 / BigDecimal("3"))) - MarketData::FOUNDING_PARTNER_QUOTA - MarketData::FOUNDATION_RESERVE_QUOTA - bug_bounty_address.balance
    expected_circulating_supply = (result / (10**8)).truncate(8)

    assert_equal expected_circulating_supply, MarketData.new.send(:circulating_supply)
  end

  test "ecosystem_locked should return 97% of ecosystem quota when current time is before first released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2019-11-30")))

    assert_equal MarketData::ECOSYSTEM_QUOTA * 0.97, MarketData.new.send(:ecosystem_locked)
  end

  test "ecosystem_locked should return 75% of ecosystem quota when current time is after first released time but before second released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-08-02")))

    assert_equal MarketData::ECOSYSTEM_QUOTA * 0.75, MarketData.new.send(:ecosystem_locked)
  end

  test "ecosystem_locked should return 50% of ecosystem quota when current time is after second released time but before third released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2021-08-02")))

    assert_equal MarketData::ECOSYSTEM_QUOTA * 0.5, MarketData.new.send(:ecosystem_locked)
  end

  test "ecosystem_locked should return zero when current time is after third released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2023-08-02")))

    assert_equal 0, MarketData.new.send(:ecosystem_locked)
  end

  test "team_locked should return 2/3 of team quota when current time is before first released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2019-11-30")))

    assert_equal MarketData::TEAM_QUOTA * (2 / BigDecimal("3")), MarketData.new.send(:team_locked)
  end

  test "team_locked should return 50% of team quota when current time is after first released time but before second released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-08-02")))

    assert_equal MarketData::TEAM_QUOTA * 0.5, MarketData.new.send(:team_locked)
  end

  test "team_locked should return 1/3 of team quota when current time is after second released time but before third released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2021-08-02")))

    assert_equal MarketData::TEAM_QUOTA * (1 / BigDecimal("3")), MarketData.new.send(:team_locked)
  end

  test "team_locked should return zero when current time is after third released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2023-08-02")))

    assert_equal 0, MarketData.new.send(:team_locked)
  end

  test "founding_partners_locked should return full of founding_partners quota when current time is before first released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2019-11-30")))

    assert_equal MarketData::FOUNDING_PARTNER_QUOTA, MarketData.new.send(:founding_partners_locked)
  end

  test "founding_partners_locked should return 75% of founding partners quota when current time is after first released time but before second released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2020-08-02")))

    assert_equal MarketData::FOUNDING_PARTNER_QUOTA * 0.75, MarketData.new.send(:founding_partners_locked)
  end

  test "founding_partners_locked should return 50% of founding partners quota when current time is after second released time but before third released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2021-08-02")))

    assert_equal MarketData::FOUNDING_PARTNER_QUOTA * 0.5, MarketData.new.send(:founding_partners_locked)
  end

  test "founding_partners_locked should return zero when current time is after third released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2023-08-02")))

    assert_equal 0, MarketData.new.send(:founding_partners_locked)
  end

  test "private_sale_locked should return 1/3 of private_sale quota when current time is before released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2019-11-30")))

    assert_equal MarketData::PRIVATE_SALE_QUOTA * (1 / BigDecimal("3")), MarketData.new.send(:private_sale_locked)
  end

  test "private_sale_locked should return zero when current time is after released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2023-08-02")))

    assert_equal 0, MarketData.new.send(:private_sale_locked)
  end

  test "foundation_reserve_locked should return full of foundation_reserve quota when current time is before released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2019-11-30")))

    assert_equal MarketData::FOUNDATION_RESERVE_QUOTA, MarketData.new.send(:foundation_reserve_locked)
  end

  test "foundation_reserve_locked should return zero when current time is after released time" do
    MarketData.any_instance.stubs(:current_timestamp).returns(CkbUtils.time_in_milliseconds(Time.find_zone("UTC").parse("2023-08-02")))

    assert_equal 0, MarketData.new.send(:private_sale_locked)
  end
end
