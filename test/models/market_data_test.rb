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
end
