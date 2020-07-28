require "test_helper"

module Charts
  class AddressAverageDepositTimeGeneratorTest < ActiveSupport::TestCase
    test "should return zero when an address's total deposit is zero" do
      addr = create(:address, is_depositor: true)
      AddressAverageDepositTimeGenerator.new.perform

      assert_equal 0, addr.reload.average_deposit_time
    end
  end
end
