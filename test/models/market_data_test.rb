require "test_helper"

class MarketDataTest < ActiveSupport::TestCase
  test "total_supply should return right value" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    latest_dao = Block.recent.pick(:dao)
    parsed_dao = CkbUtils.parse_dao(latest_dao)
    result = parsed_dao.c_i - (336 * 10**16 * 0.25).to_d
    expected_circulating_supply = result / 10**8

    assert_equal expected_circulating_supply, MarketData.new.send(:total_supply)
  end

  test "circulating_supply should return right value" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2019-11-30"))
    latest_dao = Block.recent.pick(:dao)
    parsed_dao = CkbUtils.parse_dao(latest_dao)
    result = parsed_dao.c_i - MarketData::BURN_QUOTA - MarketData::ECOSYSTEM_QUOTA * 0.97 -
      MarketData::TEAM_QUOTA * (2 / 3.to_d) - MarketData::PRIVATE_SALE_QUOTA * (1 / 3.to_d) - MarketData::FOUNDING_PARTNER_QUOTA - MarketData::FOUNDATION_RESERVE_QUOTA
    expected_circulating_supply = (result / 10**8).truncate(8)

    assert_equal expected_circulating_supply, MarketData.new.send(:circulating_supply)
  end

  test "ecosystem_locked should return 97% of ecosystem quota when current time is before first released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2019-11-30"))

    assert_equal MarketData::ECOSYSTEM_QUOTA * 0.97, MarketData.new.send(:ecosystem_locked)
  end

  test "ecosystem_locked should return 75% of ecosystem quota when current time is after first released time but before second released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2020-08-02"))

    assert_equal MarketData::ECOSYSTEM_QUOTA * 0.75, MarketData.new.send(:ecosystem_locked)
  end

  test "ecosystem_locked should return 50% of ecosystem quota when current time is after second released time but before third released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2021-08-02"))

    assert_equal MarketData::ECOSYSTEM_QUOTA * 0.5, MarketData.new.send(:ecosystem_locked)
  end

  test "ecosystem_locked should return zero when current time is after third released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2023-08-02"))

    assert_equal 0, MarketData.new.send(:ecosystem_locked)
  end

  test "team_locked should return 2/3 of team quota when current time is before first released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2019-11-30"))

    assert_equal MarketData::TEAM_QUOTA * (2 / 3.to_d), MarketData.new.send(:team_locked)
  end

  test "team_locked should return 50% of team quota when current time is after first released time but before second released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2020-08-02"))

    assert_equal MarketData::TEAM_QUOTA * 0.5, MarketData.new.send(:team_locked)
  end

  test "team_locked should return 1/3 of team quota when current time is after second released time but before third released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2021-08-02"))

    assert_equal MarketData::TEAM_QUOTA * (1 / 3.to_d), MarketData.new.send(:team_locked)
  end

  test "team_locked should return zero when current time is after third released time" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    MarketData.any_instance.stubs(:current_time).returns(Time.zone.parse("2023-08-02"))

    assert_equal 0, MarketData.new.send(:team_locked)
  end
end
