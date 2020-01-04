require "test_helper"

module Charts
  class DailyStatisticGeneratorTest < ActiveSupport::TestCase
    test "should create daily statistic record" do
      block = create(:block, dao: "0xaff1568bbe49672f8a02516252ab2300df8c9e15dad428000035a1d671700007")
      tx = create(:ckb_transaction, block: block)
      create(:cell_output, cell_type: "nervos_dao_deposit", generated_by: tx, ckb_transaction: tx, block: block, capacity: 10**8 * 1000, block_timestamp: (Time.current - 1.day).end_of_day.strftime("%Q"))
      assert_difference -> { ::DailyStatistic.count }, 1 do
        Charts::DailyStatisticGenerator.new.call
      end
    end
  end
end
