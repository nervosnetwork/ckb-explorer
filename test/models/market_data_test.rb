require "test_helper"

class MarketDataTest < ActiveSupport::TestCase
  test "circulating_supply should return right value" do
    create(:block, dao: "0x80d6ccc02604d52ebc30325a84902300e7d511536bb20a00002b5625ba150007")
    latest_dao = Block.recent.pick(:dao)
    parsed_dao = CkbUtils.parse_dao(latest_dao)
    result = parsed_dao.c_i - (336 * 10**16 * 0.25).to_d
    expected_circulating_supply = result / 10**8

    assert_equal expected_circulating_supply, MarketData.new.circulating_supply
  end
end
