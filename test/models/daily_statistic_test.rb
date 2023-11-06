require "test_helper"

class DailyStatisticTest < ActiveSupport::TestCase
  test "valid_indicators should only return valid indicators" do
    create(:daily_statistic)
    attrs = DailyStatistic.valid_indicators.first.attribute_names + %w(burnt liquidity)
    assert_equal (DailyStatistic::VALID_INDICATORS + %w(id updated_at)).sort, attrs.sort
  end
end
